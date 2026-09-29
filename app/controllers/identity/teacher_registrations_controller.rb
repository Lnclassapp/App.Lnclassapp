# 🌐 DELIVERY · Identity::TeacherRegistrationsController
# Rôle : inscription enseignant publique, par code saisi ou lien /e/<code>?ref= (limité en débit, parrain noté) ; succès : session
# ADR  : 0026, 0028, 0030, 0050, 0057, 0063 · UDR : 0024, 0044, 0050
module Identity
  class TeacherRegistrationsController < ApplicationController
    FIELDS = %i[last_name first_name gender contact pin pin_confirmation school_code material_slug ref].freeze

    allow_unauthenticated_access
    rate_limit to: 5, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { render_rate_limited(:new) }
    # ADR-0057 : l'aperçu d'un code a son propre compteur, comme /c/<code> (ADR-0041) ; au-delà, rien n'est révélé.
    rate_limit to: 10, within: 1.minute, only: :with_code, name: "school_code", by: -> { request.remote_ip },
               with: -> { refuse_too_many }
    helper_method :material_options

    def new
      return redirect_to_home if authenticated?

      @form = Dtos::Identity::TeacherRegistrationInput.new
    end

    # /e/<code> : le même formulaire, l'établissement déjà trouvé ; un code refusé répond 404 sans dire pourquoi. Le jeton
    # du parrain (?ref=, ADR-0063) voyage dans un champ caché, sans cookie ni session.
    def with_code
      return redirect_to_home if authenticated?

      @form = Dtos::Identity::TeacherRegistrationInput.new(school_code: params[:code], ref: params[:ref])
      @preview = preview_of(@form.school_code)
      @invalid_code = @preview.nil?
      render :new, status: @invalid_code ? :not_found : :ok
    end

    def create
      @form = form_input
      result = register.call(actor: current_actor, dto: @form, ip: request.remote_ip, user_agent: request.user_agent)
      # Un code bon, refusé pour une autre raison (PIN…) : le bandeau de l'établissement remplace le champ.
      @preview = preview_of(@form.school_code) if result.failure? && !result.errors.key?(:school_code)
      render_result result, form: :new, success: lambda { |registered|
        start_session(registered.token)
        redirect_to teacher_classrooms_path, notice: t(".welcome"), status: :see_other
      }
    end

    private

    def refuse_too_many
      @rate_limited = true
      render :new, status: :too_many_requests
    end

    def form_input
      Dtos::Identity::TeacherRegistrationInput.new(**params.expect(teacher_registration: FIELDS).to_h.symbolize_keys)
    end

    def preview_of(code) = Queries::School::SchoolCodePreviewQuery.new.call(code:)
    def material_options = Queries::Catalog::ReferentialOptionsQuery.new.call.materials.map { [ it.name, it.slug ] }

    def register
      UseCases::Identity::RegisterTeacher.new(
        registrations: Repositories::Identity::RegistrationRepository.new, schools: Repositories::School::SchoolRepository.new,
        taxonomy: Repositories::Catalog::TaxonomyRepository.new, sessions: Repositories::Identity::SessionRepository.new,
        referrals: Repositories::Identity::ReferralRepository.new,
        policy: Policies::Identity::RegisterTeacherPolicy.new, transaction: Repositories::Shared::Transaction.new,
        digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
