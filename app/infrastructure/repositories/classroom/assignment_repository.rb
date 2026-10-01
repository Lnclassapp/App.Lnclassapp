# 🔌 INFRA · Repositories::Classroom::AssignmentRepository
# Rôle : assignations d'une classe ; résout la ressource (cours, fiche, exercice) par son type, sans association polymorphe
# ADR  : 0035, 0048
module Repositories
  module Classroom
    class AssignmentRepository
      include Ports::Classroom::AssignmentRepositoryPort

      # type → [modèle, colonne de clé, colonne de nom]
      RESOURCES = {
        "Course" => [ "Orm::Course", :slug, :name ],
        "Essential" => [ "Orm::Essential", :slug, :name ],
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
          assigned_by_id: assignment.assigned_by_id, assigned_at: assignment.assigned_at
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

      def resolve_assignable(type:, key:)
        case type
        when "Course" then resolve_course(key)
        when "Essential" then resolve_essential(key)
        when "Exercise" then resolve_exercise(key)
        end
      end

      private

      def resolve_course(slug)
        record = Orm::Course.find_by(slug:)
        record && resolved("Course", record, key: record.slug, name: record.name, parents: [], course: record)
      end

      def resolve_essential(slug)
        record = Orm::Essential.includes(:course).find_by(slug:)
        record && resolved("Essential", record, key: record.slug, name: record.name, parents: [ record.course ], course: record.course)
      end

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
          assigned_by_id: record.assigned_by_id, assigned_at: record.assigned_at, archived_at: record.archived_at
        )
      end
    end
  end
end
