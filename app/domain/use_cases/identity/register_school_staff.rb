# 🧠 DOMAINE · UseCases::Identity::RegisterSchoolStaff
# Rôle : inscrit une direction (rôle imposé) par le code d'un établissement actif, sous le plafond, et ouvre sa session
# ADR  : 0028, 0050, 0057, 0077 · UDR : 0070
module UseCases
  module Identity
    class RegisterSchoolStaff
      Registered = Data.define(:user, :token)
      ROLE = "school_admin".freeze
      JOINED_VIA = "code".freeze
      INVALID_CODE = { school_code: [ :inclusion ] }.freeze
      CAP_REACHED = { base: [ :cap_reached ] }.freeze

      # Un refus après la création du compte traverse la transaction pour l'annuler, puis ressort en Result.
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("inscription annulée : #{result.code}")
        end
      end

      def initialize(registrations:, schools:, staffs:, sessions:, audit_log:, policy:, transaction:, digest_key:, clock:)
        @registrations = registrations
        @schools = schools
        @staffs = staffs
        @sessions = sessions
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::SchoolStaffRegistrationInput.
      # → success(Registered) | :forbidden (déjà connecté) | :invalid | :conflict (numéro pris, ou plafond atteint)
      def call(actor:, dto:, ip:, user_agent:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        # Code inconnu, remplacé, ou d'un établissement inactif ou en brouillon : la même erreur, rien n'est révélé.
        school = @schools.find_by_school_code(school_code: dto.school_code)
        return Shared::Result.failure(:invalid, errors: INVALID_CODE) unless school&.active?

        register(dto, school, ip, user_agent)
      rescue Aborted => e
        e.result
      end

      private

      # Le plafond est compté sous le verrou de l'établissement (ADR-0077 §6) : refusé, il annule le compte créé.
      def register(dto, school, ip, user_agent)
        now = @clock.now
        @transaction.call do
          user = written(@registrations.create_school_admin(user: user_from(dto), pin: dto.pin))
          attached = @staffs.attach_by_code(user_id: user.id, school_id: school.id, cap: Entities::School::Staff::CODE_CAP, at: now)
          raise Aborted, Shared::Result.failure(:conflict, errors: CAP_REACHED) unless attached

          token = open_session(user, ip, user_agent, now)
          @audit_log.record(action: "school_staff.registered", actor_id: user.id, at: now, subject_type: "User",
                            subject_id: user.id, metadata: { school_id: school.id, joined_via: JOINED_VIA }, ip:)
          Shared::Result.success(Registered.new(user:, token:))
        end
      end

      def user_from(dto)
        Entities::Identity::User.new(last_name: dto.last_name, first_name: dto.first_name, contact: dto.contact,
                                     gender: dto.gender, role: ROLE)
      end

      def written(result)
        raise Aborted, result if result.failure?

        result.value
      end

      def open_session(user, ip, user_agent, now)
        token = Entities::Identity::SecretDigest.generate_token
        @sessions.create(user_id: user.id, token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key),
                         ip:, user_agent:, at: now)
        token
      end
    end
  end
end
