# 🔌 INFRA · Repositories::Classroom::AssignmentRepository
# Rôle : assignations d'une classe et leur échéance ; résout l'exercice assigné, seul type assignable, sans association polymorphe
# ADR  : 0035, 0048, 0071, 0072
module Repositories
  module Classroom
    class AssignmentRepository
      include Ports::Classroom::AssignmentRepositoryPort

      # type → [modèle, colonne de clé, colonne de nom] ; seul l'exercice s'assigne (ADR-0072 §4.1).
      RESOURCES = {
        "Exercise" => [ "Orm::Exercise", :public_id, :title ]
      }.freeze

      def active_for(classroom_id:, assignable:)
        record = Orm::ClassroomAssignment.find_by(classroom_id:, assignable_type: assignable.type,
                                                  assignable_id: assignable.id, status: "active")
        record && map_to_entity(record, assignable)
      end

      def find_by_public_id(public_id:)
        record = Orm::ClassroomAssignment.find_by(public_id:)
        record && map_to_entity(record, assignable_of(record.assignable_type, record.assignable_id))
      end

      def create(assignment:)
        record = Orm::ClassroomAssignment.new(
          public_id: assignment.public_id, classroom_id: assignment.classroom_id,
          assignable_type: assignment.assignable.type, assignable_id: assignment.assignable.id, status: "active",
          assigned_by_id: assignment.assigned_by_id, assigned_at: assignment.assigned_at, due_on: assignment.due_on
        )
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
        Orm::ClassroomAssignment.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(map_to_entity(record, assignment.assignable))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { base: [ :already_assigned ] })
      end

      def archive(id:, archived_by_id:, at:)
        Orm::ClassroomAssignment.where(id:, status: "active")
                                .update_all(status: "archived", archived_by_id:, archived_at: at, updated_at: at)
        true
      end

      # Un seul UPDATE (ADR-0071 §6) : statut, archived_at et archived_by_id ensemble, la contrainte
      # classroom_assignments_archived_at_iff_archived tient.
      def archive_all_by_teacher_in_school(teacher_id:, school_id:, archived_by_id:, at:)
        Orm::ClassroomAssignment.where(assigned_by_id: teacher_id, status: "active",
                                       classroom_id: Orm::Classroom.where(school_id:).select(:id))
                                .update_all(status: "archived", archived_by_id:, archived_at: at, updated_at: at)
      end

      # Un autre type que l'exercice ne se résout pas : nil.
      def resolve_assignable(type:, key:)
        resolve_exercise(key) if type == "Exercise"
      end

      private

      def resolve_exercise(public_id)
        record = Orm::Exercise.includes(essential: :course).find_by(public_id:)
        record && resolved("Exercise", record, key: record.public_id, name: record.title,
                                                parents: [ record.essential, record.essential.course ], course: record.essential.course)
      end

      def resolved(type, record, key:, name:, parents:, course:)
        ResolvedAssignable.new(assignable: Entities::Classroom::Assignable.new(type:, id: record.id, key:, name:),
                               status: record.status, parents_published: parents.all? { |parent| parent.status == "published" },
                               course_level: { level_id: course.level_id, series_id: course.series_id })
      end

      def assignable_of(type, id)
        model, key_column, name_column = RESOURCES.fetch(type)
        key, name = model.constantize.where(id:).pick(key_column, name_column)
        Entities::Classroom::Assignable.new(type:, id:, key:, name:)
      end

      def map_to_entity(record, assignable)
        Entities::Classroom::Assignment.new(
          id: record.id, public_id: record.public_id, classroom_id: record.classroom_id, assignable:, status: record.status,
          assigned_by_id: record.assigned_by_id, assigned_at: record.assigned_at, archived_at: record.archived_at,
          due_on: record.due_on
        )
      end
    end
  end
end
