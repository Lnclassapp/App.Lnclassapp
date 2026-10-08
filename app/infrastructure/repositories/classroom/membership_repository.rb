# 🔌 INFRA · Repositories::Classroom::MembershipRepository
# Rôle : adhésions des élèves (classroom_students) ; une seule classe principale active (index partiel), voie d'arrivée, retrait
# ADR  : 0036, 0040, 0085
module Repositories
  module Classroom
    class MembershipRepository
      include Ports::Classroom::MembershipRepositoryPort

      COLUMNS = [ :classroom_id, :student_id, :primary, :joined_at, :left_at, "classrooms.status", :joined_via, :removed_at ].freeze
      REOPENED = { primary: true, left_at: nil, removed_at: nil, removed_by_id: nil }.freeze

      def primary_for(student_id:)
        row = Orm::ClassroomStudent.joins(:classroom).where(student_id:, primary: true, left_at: nil).pick(*COLUMNS)
        row && map_to_entity(row)
      end

      # Une ligne par élève et par classe (index unique) : celle d'un élève parti est rouverte, jamais doublée.
      def add_primary(classroom_id:, student_id:, via:, at:)
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
        Orm::ClassroomStudent.transaction(requires_new: true) do
          closed = Orm::ClassroomStudent.where(classroom_id:, student_id:).where.not(left_at: nil)
          if closed.update_all(REOPENED.merge(joined_at: at, joined_via: via)).zero?
            Orm::ClassroomStudent.create!(classroom_id:, student_id:, primary: true, joined_at: at, joined_via: via)
          end
        end
        ::Shared::Result.success
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { base: [ :already_member ] })
      end

      def leave_primary(student_id:, at:)
        Orm::ClassroomStudent.where(student_id:, primary: true, left_at: nil).update_all(left_at: at)
        true
      end

      def remove(classroom_id:, student_id:, removed_by_id:, at:)
        Orm::ClassroomStudent.where(classroom_id:, student_id:, left_at: nil)
                             .update_all(left_at: at, removed_at: at, removed_by_id:).positive?
      end

      def removed_from?(classroom_id:, student_id:)
        Orm::ClassroomStudent.where(classroom_id:, student_id:).where.not(removed_at: nil).exists?
      end

      def leave_all(student_id:, at:)
        Orm::ClassroomStudent.where(student_id:, left_at: nil).update_all(left_at: at)
        true
      end

      private

      def map_to_entity(row)
        classroom_id, student_id, primary, joined_at, left_at, classroom_status, joined_via, removed_at = row
        Entities::Classroom::Membership.new(classroom_id:, student_id:, primary:, joined_at:, left_at:, classroom_status:,
                                            joined_via:, removed_at:)
      end
    end
  end
end
