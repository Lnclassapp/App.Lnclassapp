# 🧠 DOMAINE · UseCases::Identity::RegisterTeacher
# Rôle : inscrit un enseignant (rôle imposé), le rattache à l'établissement de son code, note son parrain, ouvre sa session
# ADR  : 0026, 0028, 0030, 0050, 0057, 0063 · UDR : 0024, 0044, 0050
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

      def initialize(registrations:, schools:, taxonomy:, sessions:, referrals:, policy:, transaction:, digest_key:, clock:)
        @registrations = registrations
        @referrals = referrals
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
          record_referrer(dto.ref, user, school, now)
          Shared::Result.success(Registered.new(user:, token: open_session(user, ip, user_agent, now)))
        end
      end

      # Le parrain doit enseigner dans l'établissement actif du code (ADR-0063) ; sinon, ni parrain ni erreur. Un refus de
      # la base (filleul déjà parrainé) n'annule pas l'inscription.
      def record_referrer(token, user, school, now)
        referrer = token && @referrals.find_referrer(token:)
        return unless referrer&.school_active && referrer.school_id == school.id

        @referrals.record_referral(referrer_id: referrer.user_id, referee_id: user.id, school_id: school.id, source: "link", at: now)
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
