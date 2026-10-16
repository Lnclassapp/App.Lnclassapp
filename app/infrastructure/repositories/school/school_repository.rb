# 🔌 INFRA · Repositories::School::SchoolRepository
# Rôle : traduit Orm::School ↔ Entities::School::School ; codes d'établissement (un par un, en masse), insertion en masse, génération, enseignants
# ADR  : 0030, 0036, 0039, 0056, 0057, 0063, 0071, 0083, 0096 · UDR : 0079 · aucune recherche par code national (IE-21)
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

      # ADR-0096 §4.5 : la sélection est celle de la liste (Orm::School.list_filtered), bornée au lancement.
      def count_for_code_regeneration(selection:, created_before:)
        regeneration_scope(selection, created_before).count
      end

      def code_regeneration_batch(selection:, created_before:, after_id:, limit:)
        regeneration_scope(selection, created_before).where(id: (after_id + 1)..).order(:id).limit(limit)
                                                     .pluck(:id, :public_id, :name, :school_code_rotated_at)
                                                     .map { |id, public_id, name, rotated_at| candidate(id, public_id, name, rotated_at) }
      end

      # Un seul UPDATE … FROM (VALUES …) ; la garde « inchangé depuis » est dans la requête, sous le verrou de ligne de
      # l'UPDATE : un « Régénérer le code » concurrent passe avant (et la ligne est écartée) ou après. Pas de rescue : un code
      # pris lève, l'appelant écrit dans TransactionPort#attempt.
      def replace_school_codes(rows:, at:, unchanged_since:)
        return [] if rows.empty?

        values = rows.map { |row| Orm::School.sanitize_sql_array([ "(?::bigint, ?)", row.fetch(:id), row.fetch(:school_code) ]) }
        Orm::School.connection.exec_query(Orm::School.sanitize_sql_array([ <<~SQL.squish, at, at, unchanged_since ])).rows.flatten
          UPDATE schools SET school_code = v.code, school_code_rotated_at = ?, updated_at = ?
          FROM (VALUES #{values.join(', ')}) AS v(id, code)
          WHERE schools.id = v.id AND (schools.school_code_rotated_at IS NULL OR schools.school_code_rotated_at < ?)
          RETURNING schools.id
        SQL
      end

      # NOT EXISTS sur l'index (school_id, school_year, name) des classes ; lecture par clé, sans OFFSET.
      def without_classrooms(school_year:, after_id:, limit:)
        classrooms = Orm::Classroom.where(school_year:).where("classrooms.school_id = schools.id")
        Orm::School.where(status: GENERATION_STATUSES).where(id: (after_id + 1)..).where.not(classrooms.arel.exists)
                   .order(:id).limit(limit).pluck(*INSERTED_COLUMNS)
                   .map { |values| Inserted.new(**INSERTED_COLUMNS.map(&:to_sym).zip(values).to_h) }
      end

      def first_cycle_after(after_id:, limit:)
        Orm::School.where(cycle: "first", status: GENERATION_STATUSES).where(id: (after_id + 1)..).order(:id).limit(limit)
                   .map { map_to_entity(it) }
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

      def detach_teacher(teacher_id:, school_id:) = Orm::TeacherSchool.where(teacher_id:, school_id:).delete_all

      private

      def attributes_of(school) = ATTRIBUTES.index_with { |attribute| school.public_send(attribute) }

      def regeneration_scope(selection, created_before)
        Orm::School.regeneration_selection(selection).where(created_at: ..created_before)
      end

      def candidate(id, public_id, name, rotated_at)
        Entities::School::RegenerationCandidate.new(id:, public_id:, label: name, school_id: id, rotated_at:)
      end

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
