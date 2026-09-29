# 🌐 DELIVERY · Identity::SecondFactorEnrollmentsController
# Rôle : activation TOTP d'un compte team (QR code, secret, premier code) ; les codes de secours sont rendus sans redirection
# ADR  : 0026, 0031
module Identity
  class SecondFactorEnrollmentsController < ApplicationController
    OTPAUTH = %r{\Aotpauth://totp/}

    allow_unverified_second_factor
    before_action :leave_when_enrolled
    # La clé TOTP (y compris le 422 qui remontre le QR) et les codes de secours ne restent dans aucun cache.
    secret_response :new, :create

    def new
      render_result begin_enrollment.call(session: current_session), success: lambda { |enrollment|
        @enrollment = enrollment
        @form = Dtos::Identity::SecondFactorCodeInput.new
      }
    end

    # Les codes ne passent ni par le flash ni par la session : ils ne sont écrits que dans cette réponse.
    def create
      @form = Dtos::Identity::SecondFactorCodeInput.new(code: enrollment_params[:code])
      @enrollment = submitted_enrollment
      render_result confirm.call(session: current_session, dto: @form), form: :new, success: lambda { |codes|
        @backup_codes = codes
        respond_to do |format|
          format.turbo_stream { render turbo_stream: [ helpers.turbo_stream_secret_response, turbo_stream.replace("second-factor-enrollment", template: "identity/second_factor_enrollments/backup_codes") ] }
          format.html { render :backup_codes }
        end
      }
    end

    private

    def leave_when_enrolled
      return redirect_to_home if current_actor

      redirect_to main_app.new_identity_second_factor_path if current_session.second_factor_confirmed
    end

    def enrollment_params = params.expect(second_factor: %i[code secret secret_uri])

    # Le formulaire re-rendu en 422 remontre le même QR code : le secret enregistré n'a pas changé.
    def submitted_enrollment
      uri = enrollment_params[:secret_uri].to_s
      Ports::Identity::SecondFactorRepositoryPort::Enrollment.new(
        secret: enrollment_params[:secret].to_s, provisioning_uri: uri.match?(OTPAUTH) ? uri : ""
      )
    end

    def begin_enrollment
      UseCases::Identity::BeginSecondFactorEnrollment.new(
        users: Repositories::Identity::UserRepository.new, second_factors: Repositories::Identity::SecondFactorRepository.new,
        policy: Policies::Identity::SecondFactorPolicy.new
      )
    end

    def confirm
      UseCases::Identity::ConfirmSecondFactorEnrollment.new(
        second_factors: Repositories::Identity::SecondFactorRepository.new, sessions: Repositories::Identity::SessionRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy: Policies::Identity::SecondFactorPolicy.new, digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
