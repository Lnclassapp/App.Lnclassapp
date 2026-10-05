# 🔌 INFRA · Repositories::Classroom::MembershipRepository
# Rôle : adhésions des élèves (classroom_students) ; une seule classe principale active, garantie par l'index partiel
# ADR  : 0036, 0040
module Repositories
  module Classroom
    class MembershipRepository
      include Ports::Classroom::MembershipRepositoryPort

      COLUMNS = [ :classroom_id, :student_id, :primary, :joined_at, :left_at, "classrooms.status" ].freeze

      def primary_for(student_id:)
        row = Orm::ClassroomStudent.joins(:classroom).where(student_id:, primary: true, left_at: nil).pick(*COLUMNS)
        row && map_to_entity(row)
      end

      def add_primary(classroom_id:, student_id:, at:)
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
        Orm::ClassroomStudent.transaction(requires_new: true) do
          Orm::ClassroomStudent.create!(classroom_id:, student_id:, primary: true, joined_at: at)
        end
        ::Shared::Result.success
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { base: [ :already_member ] })
      end

      def leave_primary(student_id:, at:)
        Orm::ClassroomStudent.where(student_id:, primary: true, left_at: nil).update_all(left_at: at)
        true
      end

      def leave_all(student_id:, at:)
        Orm::ClassroomStudent.where(student_id:, left_at: nil).update_all(left_at: at)
        true
      end

      private

      def map_to_entity(row)
        classroom_id, student_id, primary, joined_at, left_at, classroom_status = row
        Entities::Classroom::Membership.new(classroom_id:, student_id:, primary:, joined_at:, left_at:, classroom_status:)
      end
    end
  end
end
