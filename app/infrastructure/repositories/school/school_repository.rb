# 🔌 INFRA · Repositories::School::SchoolRepository
# Rôle : traduit Orm::School ↔ Entities::School::School ; insertion en masse des imports, rattachement des enseignants
# ADR  : 0030, 0036, 0039
module Repositories
  module School
    class SchoolRepository
      include Ports::School::SchoolRepositoryPort

      INSERTED_COLUMNS = %w[id public_id drena_id name school_type cycle].freeze
      ATTRIBUTES = %i[drena_id name sigle school_type cycle status].freeze

      def find_by_public_id(public_id:)
        record = Orm::School.find_by(public_id:)
        record && map_to_entity(record)
      end

      def create(school:)
        persist(Orm::School.new(attributes_of(school)))
      end

      def update(school:)
        record = Orm::School.find(school.id)
        record.assign_attributes(attributes_of(school))
        persist(record)
      end

      # Les classes partent avec l'école, pourvu qu'aucune ne soit utilisée ; appelé dans la transaction du use case.
      def delete_if_unreferenced(id:)
        classroom_ids = Orm::Classroom.where(school_id: id).select(:id)
        if referenced?(id, classroom_ids)
          return ::Shared::Result.failure(:conflict, errors: { base: [ :referenced ] })
        end

        Orm::Classroom.where(school_id: id).delete_all
        Orm::School.where(id:).delete_all
        ::Shared::Result.success
      end

      def existing_keys(drena_ids:)
        Orm::School.where(drena_id: drena_ids).pluck(:drena_id, :name)
                   .to_set { |drena_id, name| [ drena_id, Entities::Shared::NaturalKey.normalize(name) ] }
      end

      # insert_all! : un doublon lève, et le moteur rejoue le lot élément par élément.
      def insert_many(rows:, at:)
        return [] if rows.empty?

        Orm::School.insert_all!(rows.map { |row| row.merge(created_at: at, updated_at: at) }, returning: INSERTED_COLUMNS)
                   .map { |row| Inserted.new(**row.symbolize_keys) }
      end

      def attach_teacher(teacher_id:, school_id:, primary:, at:)
        Orm::TeacherSchool.transaction(requires_new: true) do
          Orm::TeacherSchool.create!(teacher_id:, school_id:, primary:, created_at: at)
        end
        ::Shared::Result.success
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict)
      end

      def primary_school_id_for(teacher_id:)
        Orm::TeacherSchool.where(teacher_id:, primary: true).pick(:school_id)
      end

      private

      def attributes_of(school) = ATTRIBUTES.index_with { |attribute| school.public_send(attribute) }

      def referenced?(school_id, classroom_ids)
        Orm::TeacherSchool.exists?(school_id:) || Orm::Invitation.exists?(school_id:) ||
          Orm::ClassroomStudent.exists?(classroom_id: classroom_ids) ||
          Orm::TeacherClassroom.exists?(classroom_id: classroom_ids) ||
          Orm::ClassroomAssignment.exists?(classroom_id: classroom_ids)
      end

      # Le savepoint garde intacte la transaction du use case quand l'index unique refuse la ligne.
      def persist(record)
        Orm::School.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { name: [ :taken ] })
      end

      def map_to_entity(record)
        Entities::School::School.new(id: record.id, public_id: record.public_id, drena_id: record.drena_id,
                                     name: record.name, sigle: record.sigle, school_type: record.school_type,
                                     cycle: record.cycle, status: record.status)
      end
    end
  end
end
