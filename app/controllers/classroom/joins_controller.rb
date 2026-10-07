# 🌐 DELIVERY · Classroom::JoinsController
# Rôle : /c/<jeton> ouvre l'inscription élève, la classe déjà choisie ; /c/<code> (ancien chemin, jusqu'au Lot F) ; limités en débit
# ADR  : 0026, 0028, 0040, 0041, 0050, 0083 · UDR : 0009, 0079
module Classroom
  class JoinsController < ApplicationController
    FIELDS = %i[last_name first_name gender contact pin pin_confirmation].freeze

    allow_unauthenticated_access
    # ADR-0041, ADR-0083 §4.1 : l'aperçu et l'inscription partagent le compteur ; au-delà, rien n'est révélé.
    rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip }, with: -> { refuse_too_many }
    before_action :refuse_other_roles
    before_action :load_link, if: :link_token
    before_action :load_preview, unless: :link_token

    def new
      @form = Dtos::Classroom::JoinWithCodeInput.new
      open_link if link_token
    end

    def create
      # Le visiteur d'un lien s'inscrit par le formulaire de /student-signup : un envoi ici le ramène à la page du lien.
      return redirect_to(join_classroom_path(link_token), status: :see_other) if link_token && current_actor.nil?
      return join_as_student if current_actor

      @form = form_input
      result = join_with_code.call(actor: nil, code: @code, dto: @form, ip: request.remote_ip, user_agent: request.user_agent)
      respond_to_join(result) { |joined| start_session(joined.token) }
    end

    private

    # Un paramètre de 12 caractères hexadécimaux est un jeton de lien (UDR-0079 §3.4) ; un code de 5 caractères ne l'est
    # jamais, et garde l'ancien chemin.
    def link_token = @link_token ||= Dtos::Classroom::StudentRegistrationInput.normalize_link_token(params[:code])

    def refuse_too_many
      @rate_limited = true
      render :new, status: :too_many_requests
    end

    # Un compte non élève, ou une session d'équipe sans second facteur (sans acteur), n'a rien à faire ici.
    def refuse_other_roles
      return unless authenticated?

      render_forbidden unless current_actor && current_actor.student?
    end

    # Lien invalide (jeton inconnu ou changé, classe archivée, établissement inactif) : la voie standard, avec l'alerte.
    def load_link
      @code = link_token
      @preview = Queries::Classroom::JoinPreviewQuery.new.link(token: link_token)
      return @link_full = @preview.full if @preview

      target = current_actor ? new_student_classroom_choice_path : new_student_registration_path
      redirect_to target, flash: { link_invalid: true }, status: :see_other
    end

    # Le visiteur reçoit la page d'inscription, la classe dans son bandeau ; l'élève sans classe, la carte et son bouton ;
    # une classe complète se dit, sans formulaire.
    def open_link
      return if current_actor || @link_full

      @form = Dtos::Classroom::StudentRegistrationInput.new(link_token:)
      render "classroom/student_registrations/new"
    end

    def load_preview
      @code = Entities::Classroom::JoinCode.normalize(params[:code])
      @preview = Queries::Classroom::JoinPreviewQuery.new.call(code: @code)
      render :new, status: :not_found if @preview.nil?
    end

    # Par le lien, l'élève passe encore par le code de la classe : JoinAsStudent ne connaît que lui jusqu'au Lot B.
    def join_as_student
      @form = Dtos::Classroom::JoinWithCodeInput.new
      code = link_token ? @preview.join_code : @code
      respond_to_join(change_classroom.call(actor: current_actor, code:)) { nil }
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
