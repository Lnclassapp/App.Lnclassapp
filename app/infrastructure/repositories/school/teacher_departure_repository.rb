# 🔌 INFRA · Repositories::School::TeacherDepartureRepository
# Rôle : traduit Orm::TeacherSchoolDeparture ↔ Entities::School::TeacherDeparture ; inscrire, lire l'ouvert, fermer
# ADR  : 0071
module Repositories
  module School
    class TeacherDepartureRepository
      include Ports::School::TeacherDepartureRepositoryPort

      COLUMNS = %i[id teacher_id school_id detached_by_id detached_at reinstated_by_id reinstated_at].freeze

      def record(teacher_id:, school_id:, detached_by_id:, at:)
        map_to_entity(Orm::TeacherSchoolDeparture.create!(teacher_id:, school_id:, detached_by_id:, detached_at: at))
      end

      def open_for(teacher_id:, school_id:)
        values = Orm::TeacherSchoolDeparture.where(teacher_id:, school_id:, reinstated_at: nil).pick(*COLUMNS)
        values && Entities::School::TeacherDeparture.new(*values)
      end

      # UPDATE … WHERE reinstated_at IS NULL : une réintégration déjà faite ne se réécrit pas.
      def close(id:, reinstated_by_id:, at:)
        Orm::TeacherSchoolDeparture.where(id:, reinstated_at: nil).update_all(reinstated_by_id:, reinstated_at: at)
        true
      end

      private

      def map_to_entity(record) = Entities::School::TeacherDeparture.new(**COLUMNS.index_with { record.public_send(it) })
    end
  end
end
