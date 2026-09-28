# 🧠 DOMAINE · UseCases::Identity::RegisterPendingTeacher
# Rôle : inscrit un enseignant sans code (code national ou école de sa DRENA) : compte sans école, demande en attente, session
# ADR  : 0026, 0028, 0030, 0050, 0063 · UDR : 0024, 0050
module UseCases
  module Identity
    class RegisterPendingTeacher
      Registered = Data.define(:user, :token)
      ROLE = "teacher".freeze

      # Un refus après la création du compte traverse la transaction pour l'annuler, puis ressort en Result.
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("inscription annulée : #{result.code}")
        end
      end

      def initialize(registrations:, schools:, join_requests:, taxonomy:, sessions:, policy:, transaction:, digest_key:, clock:)
        @registrations = registrations
        @schools = schools
        @join_requests = join_requests
        @taxonomy = taxonomy
        @sessions = sessions
        @policy = policy
        @transaction = transaction
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::PendingTeacherRegistrationInput.
      # → success(Registered) | :forbidden (déjà connecté) | :invalid (établissement, matière, plafond) | :conflict
      def call(actor:, dto:, ip:, user_agent:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        school = designated_school(dto)
        material = @taxonomy.find_material(slug: dto.material_slug)
        errors = fact_errors(dto, school, material)
        return Shared::Result.failure(:invalid, errors:) if errors.any?

        register(dto, school, material, ip, user_agent)
      rescue Aborted => e
        e.result
      end

      private

      def designated_school(dto)
        return @schools.find_by_national_code(national_code: dto.national_code) if dto.national_code

        @schools.find_by_public_id(public_id: dto.school_public_id)
      end

      # Inconnu, inactif ou en brouillon : la même erreur, comme pour le code d'établissement (ADR-0057).
      def fact_errors(dto, school, material)
        errors = {}
        errors[dto.national_code ? :national_code : :school_public_id] = [ :inclusion ] unless school&.active?
        errors[:material_slug] = [ :inclusion ] if material.nil?
        return errors if errors.any?

        pending = @join_requests.pending_count(school_id: school.id)
        Entities::School::JoinRequest.room_for_another?(pending_count: pending) ? {} : { base: [ :too_many_pending ] }
      end

      def register(dto, school, material, ip, user_agent)
        now = @clock.now
        @transaction.call do
          user = written(@registrations.create_teacher(user: user_from(dto), pin: dto.pin, material_id: material.id))
          written(@join_requests.create(teacher_id: user.id, school_id: school.id, at: now))
          Shared::Result.success(Registered.new(user:, token: open_session(user, ip, user_agent, now)))
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
