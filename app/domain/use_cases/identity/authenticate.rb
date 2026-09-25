# 🧠 DOMAINE · UseCases::Identity::Authenticate
# Rôle : connexion par contact et PIN, verrouillage progressif, ouverture d'une session serveur
# ADR  : 0028 (exempté de policy : l'acteur n'existe pas encore), 0050
module UseCases
  module Identity
    class Authenticate
      Authenticated = Data.define(:user, :token)
      KIND = "pin".freeze
      # Un numéro inconnu et un PIN faux reçoivent le même message.
      INVALID = { base: [ :invalid_credentials ] }.freeze

      def initialize(users:, login_attempts:, sessions:, audit_log:, digest_key:, clock:)
        @users = users
        @login_attempts = login_attempts
        @sessions = sessions
        @audit_log = audit_log
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::CredentialsInput. → success(Authenticated) | :invalid | :locked (errors[:retry_after])
      def call(dto:)
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        now = @clock.now
        failures = @login_attempts.consecutive_failures(contact: dto.attempt_key, kind: KIND)
        retry_after = Entities::Identity::Lockout.retry_after(failures: failures.count, last_failed_at: failures.last_failed_at, now:)
        return Shared::Result.failure(:locked, errors: { retry_after: }) if retry_after

        user = @users.authenticate(contact: dto.contact, pin: dto.pin)
        return reject(dto, failures.count + 1, now) if user.nil?

        Shared::Result.success(open_session(user, dto, now))
      end

      private

      def reject(dto, failures, now)
        @login_attempts.record(contact: dto.attempt_key, user_id: nil, ip: dto.ip, succeeded: false, kind: KIND, at: now)
        audit_lock(dto, failures, now) if Entities::Identity::Lockout.tier_reached?(failures)
        Shared::Result.failure(:invalid, errors: INVALID)
      end

      def audit_lock(dto, failures, now)
        subject = @users.find_by_contact(contact: dto.contact)
        @audit_log.record(action: "login.locked", actor_id: nil, subject_type: "User", subject_id: subject&.id,
                          metadata: { kind: KIND, failures: }, ip: dto.ip, at: now)
      end

      def open_session(user, dto, now)
        @login_attempts.record(contact: dto.attempt_key, user_id: user.id, ip: dto.ip, succeeded: true, kind: KIND, at: now)
        token = Entities::Identity::SecretDigest.generate_token
        @sessions.create(user_id: user.id, token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key),
                         ip: dto.ip, user_agent: dto.user_agent, at: now)
        Authenticated.new(user:, token:)
      end
    end
  end
end
