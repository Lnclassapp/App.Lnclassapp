# 🧠 DOMAINE · UseCases::Identity::RegisterTeacher
# Rôle : inscrit un enseignant (rôle imposé), le rattache à l'établissement de son code et ouvre sa session, en une transaction
# ADR  : 0026, 0028, 0030, 0050, 0057 · UDR : 0024, 0044
module UseCases
  module Identity
    class RegisterTeacher
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

      def initialize(registrations:, schools:, taxonomy:, sessions:, policy:, transaction:, digest_key:, clock:)
        @registrations = registrations
        @schools = schools
        @taxonomy = taxonomy
        @sessions = sessions
        @policy = policy
        @transaction = transaction
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::TeacherRegistrationInput.
      # → success(Registered) | :forbidden (déjà connecté) | :invalid | :conflict (numéro pris, écriture refusée)
      def call(actor:, dto:, ip:, user_agent:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        school = @schools.find_by_school_code(school_code: dto.school_code)
        material = @taxonomy.find_material(slug: dto.material_slug)
        errors = fact_errors(school, material)
        return Shared::Result.failure(:invalid, errors:) if errors.any?

        register(dto, school, material, ip, user_agent)
      rescue Aborted => e
        e.result
      end

      private

      # Code inconnu, remplacé, ou d'un établissement inactif ou en brouillon : la même erreur, rien n'est révélé.
      def fact_errors(school, material)
        errors = {}
        errors[:school_code] = [ :inclusion ] unless school&.active?
        errors[:material_slug] = [ :inclusion ] if material.nil?
        errors
      end

      def register(dto, school, material, ip, user_agent)
        now = @clock.now
        @transaction.call do
          user = written(@registrations.create_teacher(user: user_from(dto), pin: dto.pin, material_id: material.id))
          written(@schools.attach_teacher(teacher_id: user.id, school_id: school.id, primary: true, at: now))
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
