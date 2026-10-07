# 🧠 DOMAINE · UseCases::Identity::RegisterPendingTeacher
# Rôle : inscrit un enseignant sans code (code national ou école de sa DRENA) : compte, demande validée aussitôt (pause), session
# ADR  : 0026, 0028, 0030, 0050, 0063, 0073, 0082 · UDR : 0024, 0050
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

        # L'établissement n'est jugé qu'une fois tout le reste valide : le formulaire ne sert pas d'oracle du code national.
        material = @taxonomy.find_material(slug: dto.material_slug)
        return Shared::Result.failure(:invalid, errors: { material_slug: [ :inclusion ] }) if material.nil?

        school = designated_school(dto)
        return Shared::Result.failure(:invalid, errors: { school_field(dto) => [ :inclusion ] }) unless school&.active?

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
      def school_field(dto) = dto.national_code ? :national_code : :school_public_id

      def register(dto, school, material, ip, user_agent)
        now = @clock.now
        @transaction.call do
          user = written(@registrations.create_teacher(user: user_from(dto), pin: dto.pin, material_id: material.id,
                                                       joined_via: "standard"))
          # Plafond compté et tenu sous verrou par le repository (B2), après le compte : « trop de demandes » ne se lit
          # qu'au bout d'un formulaire entièrement valide.
          request = written(@join_requests.create(teacher_id: user.id, school_id: school.id, at: now,
                                                  max_pending: Entities::School::JoinRequest::MAX_PENDING_PER_SCHOOL))
          # Validation en pause (chantier validation-enseignants-en-pause) : la demande est validée aussitôt et l'enseignant
          # rattaché ; elle reste la trace d'une inscription sans code, pour la future certification.
          written(@join_requests.approve(id: request.id, decided_by_id: nil, via: Entities::School::JoinRequest::AUTO, at: now))
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
