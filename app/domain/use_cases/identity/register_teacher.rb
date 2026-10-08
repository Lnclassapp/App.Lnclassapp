# 🧠 DOMAINE · UseCases::Identity::RegisterTeacher
# Rôle : inscrit un enseignant (rôle imposé) dans l'établissement de sa DRENA ou de son lien, note et audite sa voie, ouvre sa session
# ADR  : 0026, 0028, 0030, 0050, 0063, 0083 · UDR : 0024, 0050, 0079
module UseCases
  module Identity
    class RegisterTeacher
      Registered = Data.define(:user, :token)
      # L'établissement désigné et la voie qui y mène ; referrer_id : le collègue du lien, sinon nil.
      Destination = Data.define(:school_id, :channel, :referrer_id)
      ROLE = "teacher".freeze
      STANDARD = "standard".freeze
      COLLEAGUE = "colleague".freeze

      # Un refus après la création du compte traverse la transaction pour l'annuler, puis ressort en Result.
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("inscription annulée : #{result.code}")
        end
      end

      def initialize(registrations:, schools:, drenas:, invite_links:, taxonomy:, sessions:, referrals:, audit_log:, policy:,
                     transaction:, digest_key:, clock:)
        @registrations = registrations
        @schools = schools
        @drenas = drenas
        @invite_links = invite_links
        @taxonomy = taxonomy
        @sessions = sessions
        @referrals = referrals
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::TeacherRegistrationInput.
      # → success(Registered) | :forbidden (déjà connecté) | :invalid (formulaire, matière, établissement) | :conflict
      def call(actor:, dto:, ip:, user_agent:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        # L'établissement n'est jugé qu'une fois tout le reste valide : le formulaire ne sert pas d'oracle.
        material = @taxonomy.find_material(slug: dto.material_slug)
        return Shared::Result.failure(:invalid, errors: { material_slug: [ :inclusion ] }) if material.nil?

        destination = invited(dto.invite_token) || chosen(dto)
        return destination if destination.is_a?(Shared::Result)

        register(dto, destination, material, ip, user_agent)
      rescue Aborted => e
        e.result
      end

      private

      # Résolu de nouveau à l'envoi (ADR-0083 §4.1) : un lien valide l'emporte sur l'établissement envoyé. Un lien devenu
      # invalide retombe, sans rien dire, sur la voie standard.
      def invited(token)
        link = token && @invite_links.resolve(token:)
        Destination.new(school_id: link.school_id, channel: link.channel, referrer_id: link.referrer_id) if link&.valid?
      end

      # Inconnu, inactif, en brouillon ou d'une autre DRENA : la même erreur sur l'établissement.
      def chosen(dto)
        missing = { drena_public_id: dto.drena_public_id, school_public_id: dto.school_public_id }.select { |_, id| id.blank? }
        return Shared::Result.failure(:invalid, errors: missing.transform_values { [ :blank ] }) if missing.any?

        drena = @drenas.find_by_public_id(public_id: dto.drena_public_id)
        return Shared::Result.failure(:invalid, errors: { drena_public_id: [ :inclusion ] }) if drena.nil?

        school = @schools.find_by_public_id(public_id: dto.school_public_id)
        unless school&.active? && school.drena_id == drena.id
          return Shared::Result.failure(:invalid, errors: { school_public_id: [ :inclusion ] })
        end

        Destination.new(school_id: school.id, channel: STANDARD, referrer_id: nil)
      end

      def register(dto, destination, material, ip, user_agent)
        now = @clock.now
        @transaction.call do
          user = written(@registrations.create_teacher(user: user_from(dto), pin: dto.pin, material_id: material.id,
                                                       joined_via: destination.channel))
          written(@schools.attach_teacher(teacher_id: user.id, school_id: destination.school_id, primary: true, at: now))
          record_referral(destination, user, now)
          # ADR-0083 §4.4 bis (IE-23) : comme le rattachement depuis l'écran d'attente, avec la voie en plus.
          @audit_log.record(action: "school.changed", actor_id: user.id, at: now, subject_type: "School",
                            subject_id: destination.school_id, metadata: { change: "teacher_joined", via: destination.channel }, ip:)
          Shared::Result.success(Registered.new(user:, token: open_session(user, ip, user_agent, now)))
        end
      end

      # Le parrainage (ADR-0063) ne vaut que pour le lien d'un collègue. Un refus de la base (filleul déjà parrainé)
      # n'annule pas l'inscription.
      def record_referral(destination, user, now)
        return unless destination.channel == COLLEAGUE

        @referrals.record_referral(referrer_id: destination.referrer_id, referee_id: user.id, school_id: destination.school_id,
                                   source: "link", at: now)
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
