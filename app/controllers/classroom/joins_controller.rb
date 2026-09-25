# 🌐 DELIVERY · Classroom::JoinsController
# Rôle : /c/<code> : aperçu limité en débit ; le visiteur s'inscrit (session ouverte), l'élève connecté change de classe
# ADR  : 0026, 0028, 0040, 0041, 0050 · UDR : 0009
module Classroom
  class JoinsController < ApplicationController
    FIELDS = %i[last_name first_name gender contact pin pin_confirmation].freeze

    allow_unauthenticated_access
    # ADR-0041 : l'aperçu et l'inscription partagent le compteur ; au-delà, rien n'est révélé.
    rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip }, with: -> { refuse_too_many }
    before_action :refuse_other_roles
    before_action :load_preview

    def new
      @form = Dtos::Classroom::JoinWithCodeInput.new
    end

    def create
      return join_as_student if current_actor

      @form = form_input
      result = join_with_code.call(actor: nil, code: @code, dto: @form, ip: request.remote_ip, user_agent: request.user_agent)
      respond_to_join(result) { |joined| start_session(joined.token) }
    end

    private

    def refuse_too_many
      @rate_limited = true
      render :new, status: :too_many_requests
    end

    # Un compte non élève, ou une session d'équipe sans second facteur (sans acteur), n'a rien à faire ici.
    def refuse_other_roles
      return unless authenticated?

      render_forbidden unless current_actor && current_actor.student?
    end

    def load_preview
      @code = Entities::Classroom::JoinCode.normalize(params[:code])
      @preview = Queries::Classroom::JoinPreviewQuery.new.call(code: @code)
      render :new, status: :not_found if @preview.nil?
    end

    def join_as_student
      @form = Dtos::Classroom::JoinWithCodeInput.new
      respond_to_join(change_classroom.call(actor: current_actor, code: @code)) { nil }
    end

    # Un refus de JoinPolicy nomme sa raison : la page la montre, en 403.
    def respond_to_join(result, &opened)
      return render_refusal(result) if result.code == :forbidden

      render_result result, form: :new, success: lambda { |value|
        opened.call(value)
        redirect_to student_home_path, notice: t("classroom.joins.create.welcome"), status: :see_other
      }
    end

    def render_refusal(result)
      add_errors(result)
      render :new, status: :forbidden
    end

    def form_input
      Dtos::Classroom::JoinWithCodeInput.new(**params.expect(join: FIELDS).to_h.symbolize_keys)
    end

    def join_with_code
      UseCases::Classroom::JoinWithCode.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, registrations: Repositories::Identity::RegistrationRepository.new,
        memberships: Repositories::Classroom::MembershipRepository.new, sessions: Repositories::Identity::SessionRepository.new,
        policy: Policies::Classroom::JoinPolicy.new, transaction: Repositories::Shared::Transaction.new,
        digest_key: secret_digest_key, clock: Time.zone
      )
    end

    def change_classroom
      UseCases::Classroom::JoinAsStudent.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, memberships: Repositories::Classroom::MembershipRepository.new,
        policy: Policies::Classroom::JoinPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end
