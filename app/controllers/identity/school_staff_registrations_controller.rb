# 🌐 DELIVERY · Identity::SchoolStaffRegistrationsController
# Rôle : inscription publique de la direction avec le code d'établissement (limitée en débit) ; succès : session, « Travail des élèves »
# ADR  : 0028, 0050, 0057, 0077 · UDR : 0070
module Identity
  class SchoolStaffRegistrationsController < ApplicationController
    FIELDS = %i[last_name first_name gender contact pin pin_confirmation school_code].freeze

    allow_unauthenticated_access
    rate_limit to: 10, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { refuse_too_many }

    def new
      return redirect_to_home if authenticated?

      @form = Dtos::Identity::SchoolStaffRegistrationInput.new
    end

    def create
      @form = form_input
      result = register.call(actor: current_actor, dto: @form, ip: request.remote_ip, user_agent: request.user_agent)
      render_result result, form: :new, success: lambda { |registered|
        start_session(registered.token)
        redirect_to school_admin_classrooms_path, notice: t(".created"), status: :see_other
      }
    end

    private

    def refuse_too_many
      @rate_limited = true
      render :new, status: :too_many_requests
    end

    def form_input
      Dtos::Identity::SchoolStaffRegistrationInput.new(**params.expect(school_staff_registration: FIELDS).to_h.symbolize_keys)
    end

    def register
      UseCases::Identity::RegisterSchoolStaff.new(
        registrations: Repositories::Identity::RegistrationRepository.new, schools: Repositories::School::SchoolRepository.new,
        staffs: Repositories::School::StaffRepository.new, sessions: Repositories::Identity::SessionRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::Identity::RegisterSchoolStaffPolicy.new,
        transaction: Repositories::Shared::Transaction.new, digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
