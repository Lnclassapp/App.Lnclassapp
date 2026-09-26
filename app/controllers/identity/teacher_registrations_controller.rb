# 🌐 DELIVERY · Identity::TeacherRegistrationsController
# Rôle : inscription enseignant publique ; succès : session ouverte, déclaration des classes ; échec re-rendu en 422
# ADR  : 0026, 0028, 0030, 0050 · UDR : 0024
module Identity
  class TeacherRegistrationsController < ApplicationController
    FIELDS = %i[last_name first_name gender contact pin pin_confirmation drena_public_id school_public_id material_slug].freeze

    allow_unauthenticated_access
    rate_limit to: 5, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { render_rate_limited(:new) }
    helper_method :drena_options, :school_options, :material_options

    # Sans JavaScript, « Afficher les établissements » revient ici en GET avec la seule DRENA.
    def new
      return redirect_to_home if authenticated?

      @form = Dtos::Identity::TeacherRegistrationInput.new(
        drena_public_id: params.permit(teacher_registration: :drena_public_id).dig(:teacher_registration, :drena_public_id)
      )
    end

    def create
      @form = form_input
      result = register.call(actor: current_actor, dto: @form, ip: request.remote_ip, user_agent: request.user_agent)
      render_result result, form: :new, success: lambda { |registered|
        start_session(registered.token)
        redirect_to teacher_classrooms_path, notice: t(".welcome"), status: :see_other
      }
    end

    private

    def form_input
      Dtos::Identity::TeacherRegistrationInput.new(**params.expect(teacher_registration: FIELDS).to_h.symbolize_keys)
    end

    def drena_options = options.drenas.map { [ it.name, it.public_id ] }
    def material_options = Queries::Catalog::ReferentialOptionsQuery.new.call.materials.map { [ it.name, it.slug ] }

    def school_options
      return [] if @form.drena_public_id.blank?

      options.schools_for(drena_public_id: @form.drena_public_id)
    end

    def options = @options ||= Queries::School::SchoolOptionsQuery.new

    def register
      UseCases::Identity::RegisterTeacher.new(
        registrations: Repositories::Identity::RegistrationRepository.new, schools: Repositories::School::SchoolRepository.new,
        drenas: Repositories::School::DrenaRepository.new, taxonomy: Repositories::Catalog::TaxonomyRepository.new,
        sessions: Repositories::Identity::SessionRepository.new, policy: Policies::Identity::RegisterTeacherPolicy.new,
        transaction: Repositories::Shared::Transaction.new, digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
