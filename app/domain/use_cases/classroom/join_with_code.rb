# 🧠 DOMAINE · UseCases::Classroom::JoinWithCode
# Rôle : un visiteur rejoint une classe par son code : compte élève (rôle imposé), adhésion principale et session, en une transaction
# ADR  : 0026, 0028, 0040, 0041, 0050 · UDR : 0009
module UseCases
  module Classroom
    class JoinWithCode
      Joined = Data.define(:user, :classroom, :token)
      ROLE = "student".freeze

      # Un refus après la création du compte traverse la transaction pour l'annuler, puis ressort en Result.
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("adhésion annulée : #{result.code}")
        end
      end

      def initialize(classrooms:, registrations:, memberships:, sessions:, policy:, transaction:, digest_key:, clock:)
        @classrooms = classrooms
        @registrations = registrations
        @memberships = memberships
        @sessions = sessions
        @policy = policy
        @transaction = transaction
        @digest_key = digest_key
        @clock = clock
      end

      # code : tel que saisi ou lu dans l'adresse ; dto : Dtos::Classroom::JoinWithCodeInput.
      # → success(Joined) | :invalid | :not_found (code inconnu ou remplacé) | :forbidden (raison en errors[:base])
      #   | :conflict (numéro pris, écriture refusée)
      def call(actor:, code:, dto:, ip:, user_agent:)
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        @transaction.call { join(actor, code, dto, ip, user_agent) }
      rescue Aborted => e
        e.result
      end

      private

      # Le verrou de la classe sérialise les adhésions : l'effectif lu reste juste jusqu'au commit (ADR-0041).
      def join(actor, code, dto, ip, user_agent)
        classroom = @classrooms.lock_by_join_code(join_code: Entities::Classroom::JoinCode.normalize(code))
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:, code:)
        return allowed if allowed.failure?

        created = @registrations.create_student(user: user_from(dto), pin: dto.pin)
        return created if created.failure?

        enroll(created.value, classroom, ip, user_agent)
      end

      def enroll(user, classroom, ip, user_agent)
        now = @clock.now
        added = @memberships.add_primary(classroom_id: classroom.id, student_id: user.id, at: now)
        raise Aborted, added if added.failure?

        Shared::Result.success(Joined.new(user:, classroom:, token: open_session(user, ip, user_agent, now)))
      end

      def user_from(dto)
        Entities::Identity::User.new(last_name: dto.last_name, first_name: dto.first_name, contact: dto.contact,
                                     gender: dto.gender, role: ROLE)
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
