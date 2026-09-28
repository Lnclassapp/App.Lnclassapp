# 🌐 DELIVERY · Identity::PendingTeacherRegistrationsController
# Rôle : inscription enseignant sans code (code national, ou DRENA → établissement) ; compte en attente, session ; limité en débit
# ADR  : 0026, 0028, 0030, 0050, 0063 · UDR : 0024, 0050
module Identity
  class PendingTeacherRegistrationsController < ApplicationController
    FIELDS = %i[last_name first_name gender contact pin pin_confirmation national_code drena_public_id school_public_id
                material_slug].freeze

    allow_unauthenticated_access
    rate_limit to: 5, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { render_rate_limited(:new) }
    before_action { @pending = true }
    helper_method :material_options, :drena_options, :school_options

    # Sans JavaScript, la DRENA choisie revient ici en GET (formulaire teacher-signup-drena) et liste ses établissements.
    def new
      return redirect_to_home if authenticated?

      @form = Dtos::Identity::PendingTeacherRegistrationInput.new(
        drena_public_id: params.permit(teacher_registration: :drena_public_id).dig(:teacher_registration, :drena_public_id)
      )
    end

    def create
      @form = form_input
      result = register.call(actor: current_actor, dto: @form, ip: request.remote_ip, user_agent: request.user_agent)
      render_result result, form: :new, success: lambda { |registered|
        start_session(registered.token)
        redirect_to pending_account_path, notice: t(".done"), status: :see_other
      }
    end

    private

    def form_input
      Dtos::Identity::PendingTeacherRegistrationInput.new(**params.expect(teacher_registration: FIELDS).to_h.symbolize_keys)
    end

    def options = @options ||= Queries::School::SchoolOptionsQuery.new
    def material_options = Queries::Catalog::ReferentialOptionsQuery.new.call.materials.map { [ it.name, it.slug ] }
    def drena_options = options.drenas.map { [ it.name, it.public_id ] }

    def school_options
      return [] if @form.drena_public_id.blank?

      options.schools_for(drena_public_id: @form.drena_public_id)
    end

    def register
      UseCases::Identity::RegisterPendingTeacher.new(
        registrations: Repositories::Identity::RegistrationRepository.new, schools: Repositories::School::SchoolRepository.new,
        join_requests: Repositories::School::JoinRequestRepository.new, taxonomy: Repositories::Catalog::TaxonomyRepository.new,
        sessions: Repositories::Identity::SessionRepository.new, policy: Policies::Identity::RegisterTeacherPolicy.new,
        transaction: Repositories::Shared::Transaction.new, digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
