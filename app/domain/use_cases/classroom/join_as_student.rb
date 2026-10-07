# 🧠 DOMAINE · UseCases::Classroom::JoinAsStudent
# Rôle : un élève connecté dont la classe principale est archivée rejoint une nouvelle classe par son code
# ADR  : 0026, 0028, 0040, 0041 · UDR : 0009
module UseCases
  module Classroom
    class JoinAsStudent
      ALREADY_ENROLLED = { base: [ :already_enrolled ] }.freeze
      # ADR-0083 §4.4 : la voie historique, tant que ce chemin existe.
      VIA = "code".freeze

      # L'échec de la nouvelle adhésion traverse la transaction pour rouvrir l'ancienne, puis ressort en Result.
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("adhésion annulée : #{result.code}")
        end
      end

      def initialize(classrooms:, memberships:, policy:, transaction:, clock:)
        @classrooms = classrooms
        @memberships = memberships
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # → success(Entities::Classroom::Classroom) | :forbidden (visiteur, rôle, raison en errors[:base]) | :not_found
      #   | :conflict (classe principale encore active, écriture refusée)
      def call(actor:, code:)
        # Un visiteur n'a pas de compte à inscrire : son chemin est JoinWithCode.
        return Shared::Result.failure(:forbidden) if actor.nil?

        @transaction.call { join(actor, code) }
      rescue Aborted => e
        e.result
      end

      private

      def join(actor, code)
        classroom = @classrooms.lock_by_join_code(join_code: Entities::Classroom::JoinCode.normalize(code))
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:, code:)
        return allowed if allowed.failure?

        move(actor.user_id, classroom)
      end

      def move(student_id, classroom)
        current = @memberships.primary_for(student_id:)
        return Shared::Result.failure(:conflict, errors: ALREADY_ENROLLED) if current && current.classroom_active?

        now = @clock.now
        @memberships.leave_primary(student_id:, at: now) if current
        added = @memberships.add_primary(classroom_id: classroom.id, student_id:, via: VIA, at: now)
        raise Aborted, added if added.failure?

        Shared::Result.success(classroom)
      end
    end
  end
end
