# 🔌 INFRA · Repositories::School::JoinRequestRepository
# Rôle : demandes d'enseignants inscrits sans code ; une décision ne vaut que sur une demande en attente, et rattache l'enseignant
# ADR  : 0029, 0063
module Repositories
  module School
    class JoinRequestRepository
      include Ports::School::JoinRequestRepositoryPort

      PENDING = "pending".freeze
      ALREADY_DECIDED = { base: [ :already_decided ] }.freeze
      TOO_MANY = { base: [ :too_many_pending ] }.freeze
      FULL_NAME = Arel.sql("users.first_name || ' ' || users.last_name")
      COLUMNS = [ "school_join_requests.id", "school_join_requests.public_id", "school_join_requests.teacher_id",
                  "school_join_requests.school_id", "school_join_requests.status", FULL_NAME ].freeze

      # Le plafond tient en concurrence (B2) : la ligne de l'école est verrouillée (FOR UPDATE) jusqu'à la fin de la
      # transaction du use case, puis on compte et on insère. Savepoint : un enseignant qui a déjà une demande devient
      # :conflict sans casser la transaction englobante.
      def create(teacher_id:, school_id:, at:, max_pending:)
        record = Orm::SchoolJoinRequest.transaction(requires_new: true) do
          Orm::School.where(id: school_id).lock.pick(:id)
          next if Orm::SchoolJoinRequest.where(school_id:, status: PENDING).count >= max_pending

          Orm::SchoolJoinRequest.create!(teacher_id:, school_id:, status: PENDING, created_at: at, updated_at: at)
        end
        return ::Shared::Result.failure(:invalid, errors: TOO_MANY) if record.nil?

        ::Shared::Result.success(find_by_public_id(public_id: record.public_id))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict)
      end

      def find_by_public_id(public_id:)
        values = Orm::SchoolJoinRequest.joins(:teacher).where(public_id:).pick(*COLUMNS)
        values && Entities::School::JoinRequest.new(*values)
      end

      # UPDATE … WHERE status = 'pending' : une décision concurrente ne touche aucune ligne. Le rattachement suit, dans le
      # même point de sauvegarde : un enseignant qui a déjà une école principale annule la décision.
      def approve(id:, decided_by_id:, via:, at:)
        approved = Orm::SchoolJoinRequest.transaction(requires_new: true) do
          next false unless decided?(id, "approved", decided_by_id, via, at)

          teacher_id, school_id = Orm::SchoolJoinRequest.where(id:).pick(:teacher_id, :school_id)
          Orm::TeacherSchool.create!(teacher_id:, school_id:, primary: true, created_at: at)
        end
        approved ? ::Shared::Result.success : ::Shared::Result.failure(:conflict, errors: ALREADY_DECIDED)
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict)
      end

      def reject(id:, decided_by_id:, at:)
        return ::Shared::Result.success if decided?(id, "rejected", decided_by_id, "team", at)

        ::Shared::Result.failure(:conflict, errors: ALREADY_DECIDED)
      end

      private

      def decided?(id, status, decided_by_id, via, at)
        Orm::SchoolJoinRequest.where(id:, status: PENDING)
                              .update_all(status:, decided_at: at, decided_by_id:, decided_via: via, updated_at: at) == 1
      end
    end
  end
end
