# 🔌 INFRA · Repositories::Classroom::ClassroomRepository
# Rôle : traduit Orm::Classroom ↔ Entities::Classroom::Classroom ; code d'adhésion, verrou, génération en masse, retrait d'une classe vide
# ADR  : 0030, 0039, 0041, 0059
module Repositories
  module Classroom
    class ClassroomRepository
      include Ports::Classroom::ClassroomRepositoryPort

      JOIN_CODE_INDEX = "index_classrooms_on_join_code".freeze
      # ADR-0059 : ce qui fait qu'une classe a servi, dans l'ordre où la raison est donnée.
      USAGES = { has_students: Orm::ClassroomStudent, has_teachers: Orm::TeacherClassroom,
                 has_assignments: Orm::ClassroomAssignment }.freeze

      # random : source des codes d'adhésion, injectable pour rendre une collision reproductible.
      def initialize(random: SecureRandom)
        @random = random
      end

      def find_by_public_id(public_id:)
        record = Orm::Classroom.find_by(public_id:)
        record && map_to_entity(record)
      end

      def lock_by_join_code(join_code:)
        record = Orm::Classroom.lock.find_by(join_code:)
        record && map_to_entity(record)
      end

      # Un code déjà pris est retiré une fois ; un nom pris dans l'école et l'année donne :conflict.
      def create(classroom:)
        insert(classroom, retries: 1)
      end

      def taken_join_codes
        Orm::Classroom.where.not(join_code: nil).pluck(:join_code).to_set
      end

      # insert_all! : un code ou un nom déjà pris lève, et le moteur d'import rejoue élément par élément.
      def insert_generated(rows:, at:)
        return 0 if rows.empty?

        Orm::Classroom.insert_all!(rows.map { |row| row.merge(created_at: at, updated_at: at) }).length
      end

      def names_in(school_id:, school_year:)
        Orm::Classroom.where(school_id:, school_year:).pluck(:name).to_set
      end

      def names_in_level(school_id:, school_year:, level_id:, series_id:)
        Orm::Classroom.where(school_id:, school_year:, level_id:, series_id:).pluck(:name)
      end

      # Le verrou est celui que prend l'adhésion par code (lock_by_join_code) : un élève ne rejoint pas une classe en cours
      # de retrait. Les clés étrangères `restrict` refuseraient de toute façon ; on nomme la raison avant.
      def delete_if_unused(id:)
        return ::Shared::Result.failure(:not_found) unless Orm::Classroom.lock.exists?(id:)

        reason = usage_of(id)
        return ::Shared::Result.failure(:conflict, errors: { base: [ reason ] }) if reason

        Orm::Classroom.where(id:).delete_all
        ::Shared::Result.success
      end

      private

      def usage_of(classroom_id) = USAGES.find { |_, model| model.exists?(classroom_id:) }&.first

      def insert(classroom, retries:)
        record = Orm::Classroom.new(attributes_of(classroom).merge(join_code: Entities::Classroom::JoinCode.generate(random: @random)))
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
        Orm::Classroom.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique => error
        field = error.message.include?(JOIN_CODE_INDEX) ? :join_code : :name
        return insert(classroom, retries: retries - 1) if field == :join_code && retries.positive?

        ::Shared::Result.failure(:conflict, errors: { field => [ :taken ] })
      end

      def attributes_of(classroom)
        { school_id: classroom.school_id, level_id: classroom.level_id, series_id: classroom.series_id,
          school_year: classroom.school_year, name: classroom.name, max_students: classroom.max_students,
          status: classroom.status, public_id: classroom.public_id }
      end

      def map_to_entity(record)
        Entities::Classroom::Classroom.new(
          id: record.id, public_id: record.public_id, school_id: record.school_id, level_id: record.level_id,
          series_id: record.series_id, school_year: record.school_year, join_code: record.join_code, name: record.name,
          status: record.status, max_students: record.max_students,
          teacher_ids: Orm::TeacherClassroom.where(classroom_id: record.id).pluck(:teacher_id),
          active_students_count: Orm::ClassroomStudent.where(classroom_id: record.id, left_at: nil).count
        )
      end
    end
  end
end
