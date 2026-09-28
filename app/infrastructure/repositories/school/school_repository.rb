# 🔌 INFRA · Repositories::School::SchoolRepository
# Rôle : traduit Orm::School ↔ Entities::School::School ; codes d'établissement, insertion en masse, génération, enseignants
# ADR  : 0030, 0036, 0039, 0056, 0057, 0063, 0066
module Repositories
  module School
    class SchoolRepository
      include Ports::School::SchoolRepositoryPort

      INSERTED_COLUMNS = %w[id public_id drena_id name school_type cycle].freeze
      ATTRIBUTES = %i[drena_id name sigle school_type cycle status national_code].freeze
      NATIONAL_CODE_INDEX = "index_schools_on_national_code".freeze
      GENERATION_STATUSES = %w[active draft].freeze

      def find_by_public_id(public_id:)
        record = Orm::School.find_by(public_id:)
        record && map_to_entity(record)
      end

      def find_by_id(id:)
        record = Orm::School.find_by(id:)
        record && map_to_entity(record)
      end

      def find_by_school_code(school_code:)
        record = Orm::School.find_by(school_code:)
        record && map_to_entity(record)
      end

      def find_by_national_code(national_code:)
        record = Orm::School.find_by(national_code:)
        record && map_to_entity(record)
      end

      def taken_national_codes = Orm::School.where.not(national_code: nil).pluck(:national_code).to_set

      def create(school:)
        persist(Orm::School.new(**attributes_of(school), school_code: school.school_code))
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

      def taken_school_codes = Orm::School.pluck(:school_code).to_set

      # Savepoint : un code déjà pris (index unique) se traduit en :conflict sans casser la transaction du use case.
      def replace_school_code(id:, school_code:, at:)
        record = Orm::School.find(id)
        Orm::School.transaction(requires_new: true) { record.update!(school_code:, school_code_rotated_at: at) }
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict)
      end

      # NOT EXISTS sur l'index (school_id, school_year, name) des classes ; lecture par clé, sans OFFSET.
      def without_classrooms(school_year:, after_id:, limit:)
        classrooms = Orm::Classroom.where(school_year:).where("classrooms.school_id = schools.id")
        Orm::School.where(status: GENERATION_STATUSES).where(id: (after_id + 1)..).where.not(classrooms.arel.exists)
                   .order(:id).limit(limit).pluck(*INSERTED_COLUMNS)
                   .map { |values| Inserted.new(**INSERTED_COLUMNS.map(&:to_sym).zip(values).to_h) }
      end

      def attach_teacher(teacher_id:, school_id:, primary:, at:)
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
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

      # Dans la transaction du use case : la liaison supprimée et le départ écrit vont ensemble (ADR-0066 §4.4).
      def detach_teacher(teacher_id:, school_id:, detached_by_id:, at:)
        return ::Shared::Result.failure(:not_found) if Orm::TeacherSchool.where(teacher_id:, school_id:, primary: true).delete_all.zero?

        Orm::TeacherSchoolDeparture.create!(teacher_id:, school_id:, detached_by_id:, created_at: at)
        ::Shared::Result.success
      end

      def departed?(teacher_id:, school_id:) = Orm::TeacherSchoolDeparture.not_reinstated.exists?(teacher_id:, school_id:)

      # Verrou sur le départ ouvert ; savepoint : l'index « une école principale » refusé (enseignant rattaché entre-temps)
      # annule aussi la clôture du départ, sans casser la transaction du use case.
      def reinstate_teacher(teacher_id:, school_id:, reinstated_by_id:, at:)
        departure = Orm::TeacherSchoolDeparture.not_reinstated.lock.find_by(teacher_id:, school_id:)
        return ::Shared::Result.failure(:not_found) if departure.nil?

        Orm::TeacherSchool.transaction(requires_new: true) do
          departure.update!(reinstated_at: at, reinstated_by_id:)
          Orm::TeacherSchool.create!(teacher_id:, school_id:, primary: true, created_at: at)
        end
        ::Shared::Result.success
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { base: [ :other_school ] })
      end

      private

      def attributes_of(school) = ATTRIBUTES.index_with { |attribute| school.public_send(attribute) }

      # Une demande d'enseignant (même décidée) ou un parrainage le référencent aussi (ADR-0063) : l'historique reste.
      def referenced?(school_id, classroom_ids)
        Orm::TeacherSchool.exists?(school_id:) || Orm::Invitation.exists?(school_id:) ||
          Orm::SchoolJoinRequest.exists?(school_id:) || Orm::Referral.exists?(school_id:) ||
          Orm::ClassroomStudent.exists?(classroom_id: classroom_ids) ||
          Orm::TeacherClassroom.exists?(classroom_id: classroom_ids) ||
          Orm::ClassroomAssignment.exists?(classroom_id: classroom_ids)
      end

      # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case. L'index nommé
      # dit lequel : le code national (ADR-0063), sinon le nom dans la DRENA.
      def persist(record)
        Orm::School.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique => e
        attribute = e.message.include?(NATIONAL_CODE_INDEX) ? :national_code : :name
        ::Shared::Result.failure(:conflict, errors: { attribute => [ :taken ] })
      end

      def map_to_entity(record)
        Entities::School::School.new(id: record.id, public_id: record.public_id, drena_id: record.drena_id,
                                     name: record.name, sigle: record.sigle, school_type: record.school_type,
                                     cycle: record.cycle, status: record.status, school_code: record.school_code,
                                     national_code: record.national_code)
      end
    end
  end
end
