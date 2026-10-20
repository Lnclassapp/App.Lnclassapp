# 🔌 INFRA · Repositories::Classroom::ClassroomRepository
# Rôle : traduit Orm::Classroom ↔ Entities::Classroom::Classroom ; jeton du lien (un par un, en masse), verrou, génération en masse, retrait d'une classe vide, nom et plafond
# ADR  : 0030, 0039, 0041, 0059, 0085, 0088, 0096, 0098
module Repositories
  module Classroom
    class ClassroomRepository
      include Ports::Classroom::ClassroomRepositoryPort

      LINK_TOKEN_SQL = "substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)".freeze
      # ADR-0059 : ce qui fait qu'une classe a servi, dans l'ordre où la raison est donnée.
      USAGES = { has_students: Orm::ClassroomStudent, has_teachers: Orm::TeacherClassroom,
                 has_assignments: Orm::ClassroomAssignment }.freeze

      def find_by_public_id(public_id:)
        record = Orm::Classroom.find_by(public_id:)
        record && map_to_entity(record)
      end

      def lock_by_public_id(public_id:)
        record = Orm::Classroom.lock.find_by(public_id:)
        record && map_to_entity(record)
      end

      def lock_by_link_token(token:)
        record = token.presence && Orm::Classroom.lock.find_by(link_token: token)
        record && map_to_entity(record)
      end

      # Le jeton est tiré par la base, comme à la création : une seule source de sa forme (ADR-0085 §4.1).
      # ADR-0096 : la date du changement sert de garde au geste de masse, qui ne change pas de nouveau ce lien.
      def rotate_link_token(id:)
        now = Time.current
        Orm::Classroom.where(id:).update_all([ "link_token = #{LINK_TOKEN_SQL}, link_token_rotated_at = ?, updated_at = ?", now, now ])
        Orm::Classroom.where(id:).pick(:link_token)
      end

      # ADR-0096 §4.4 : les classes actives des établissements de la sélection de la liste, bornées au lancement.
      def count_for_link_regeneration(selection:, school_year:, created_before:)
        link_regeneration_scope(selection, school_year, created_before).count
      end

      def link_regeneration_batch(selection:, school_year:, created_before:, after_id:, limit:)
        link_regeneration_scope(selection, school_year, created_before)
          .joins(:school).where(id: (after_id + 1)..).order(:id).limit(limit)
          .pluck(:id, :public_id, "schools.name", :name, :school_id, :link_token_rotated_at)
          .map do |id, public_id, school_name, name, school_id, rotated_at|
            Entities::School::RegenerationCandidate.new(id:, public_id:, label: "#{school_name} · #{name}", school_id:, rotated_at:)
          end
      end

      # Un seul UPDATE, jetons tirés par la base ; la garde « active et inchangée depuis » est dans la requête, sous le verrou de
      # ligne de l'UPDATE (le même que « Changer le lien » et l'adhésion d'un élève). Un jeton pris lève (TransactionPort#attempt).
      def rotate_link_tokens(ids:, at:, unchanged_since:)
        return [] if ids.empty?

        Orm::Classroom.connection.exec_query(Orm::Classroom.sanitize_sql_array([ <<~SQL.squish, at, at, ids, unchanged_since ])).rows.flatten
          UPDATE classrooms SET link_token = #{LINK_TOKEN_SQL}, link_token_rotated_at = ?, updated_at = ?
          WHERE id IN (?) AND status = 'active' AND (link_token_rotated_at IS NULL OR link_token_rotated_at < ?)
          RETURNING id
        SQL
      end

      # Un nom pris dans l'école et l'année donne :conflict. Savepoint : traduit seulement une violation d'index unique,
      # sans casser la transaction du use case.
      def create(classroom:)
        record = Orm::Classroom.new(attributes_of(classroom))
        Orm::Classroom.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { name: [ :taken ] })
      end

      # insert_all! : un nom déjà pris lève, et le moteur d'import rejoue élément par élément.
      def insert_generated(rows:, at:)
        return 0 if rows.empty?

        Orm::Classroom.insert_all!(rows.map { |row| row.merge(created_at: at, updated_at: at) }).length
      end

      def names_in(school_id:, school_year:)
        Orm::Classroom.where(school_id:, school_year:).pluck(:name).to_set
      end

      def names_in_level(school_id:, school_year:, level_id:, series_id:)
        Orm::Classroom.where(school_id:, school_year:, level_id:, series_id:, status: "active").pluck(:name)
      end

      # Le verrou est celui que prend l'adhésion d'un élève (lock_by_public_id, lock_by_link_token) : un élève ne rejoint pas
      # une classe en cours de retrait. Les clés étrangères `restrict` refuseraient de toute façon ; on nomme la raison avant.
      def delete_if_unused(id:)
        return ::Shared::Result.failure(:not_found) unless Orm::Classroom.lock.exists?(id:)

        reason = usage_of(id)
        return ::Shared::Result.failure(:conflict, errors: { base: [ reason ] }) if reason

        Orm::Classroom.where(id:).delete_all
        ::Shared::Result.success
      end

      # ADR-0088 : une seule écriture pose le statut et la date, comme l'exige la contrainte « archived_at ⇔ archived ».
      def archive(id:, at:)
        record = Orm::Classroom.lock.find_by(id:)
        return ::Shared::Result.failure(:not_found) if record.nil?
        return ::Shared::Result.failure(:conflict, errors: { base: [ :already_archived ] }) if record.status == "archived"

        record.update_columns(status: "archived", archived_at: at, updated_at: at)
        ::Shared::Result.success(map_to_entity(record))
      end

      def restore(id:, at:)
        record = Orm::Classroom.lock.find_by(id:)
        return ::Shared::Result.failure(:not_found) if record.nil?
        return ::Shared::Result.failure(:conflict, errors: { base: [ :not_archived ] }) if record.status == "active"

        record.update_columns(status: "active", archived_at: nil, updated_at: at)
        ::Shared::Result.success(map_to_entity(record))
      end

      # ADR-0098 : le verrou est celui de l'adhésion d'un élève (lock_by_public_id, lock_by_link_token) ; l'effectif lu dessous
      # ne bouge plus avant l'écriture. Savepoint : un nom pris (index unique, archivées comprises) ne casse pas la transaction.
      def update_settings(id:, name:, max_students:)
        record = Orm::Classroom.lock.find_by(id:)
        return ::Shared::Result.failure(:not_found) if record.nil?
        return ::Shared::Result.failure(:conflict, errors: { base: [ :archived ] }) if record.status == "archived"

        headcount = Orm::ClassroomStudent.where(classroom_id: id, left_at: nil).count
        return ::Shared::Result.failure(:conflict, errors: { max_students: [ :below_headcount ], headcount: }) if max_students < headcount

        before = map_to_entity(record)
        Orm::Classroom.transaction(requires_new: true) { record.update!(name:, max_students:) }
        ::Shared::Result.success(Ports::Classroom::ClassroomRepositoryPort::SettingsChange.new(before:, after: map_to_entity(record)))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { suffix: [ :taken ] })
      end

      def archive_level(school_id:, school_year:, level_id:, at:)
        Orm::Classroom.where(school_id:, school_year:, level_id:, status: "active")
                      .update_all(status: "archived", archived_at: at, updated_at: at)
      end

      private

      def usage_of(classroom_id) = USAGES.find { |_, model| model.exists?(classroom_id:) }&.first

      def link_regeneration_scope(selection, school_year, created_before)
        Orm::Classroom.link_regeneration(selection, school_year).where(created_at: ..created_before)
      end

      def attributes_of(classroom)
        { school_id: classroom.school_id, level_id: classroom.level_id, series_id: classroom.series_id,
          school_year: classroom.school_year, name: classroom.name, max_students: classroom.max_students,
          status: classroom.status, public_id: classroom.public_id }
      end

      def map_to_entity(record)
        Entities::Classroom::Classroom.new(
          id: record.id, public_id: record.public_id, school_id: record.school_id, level_id: record.level_id,
          series_id: record.series_id, school_year: record.school_year, link_token: record.link_token, name: record.name,
          status: record.status, archived_at: record.archived_at, max_students: record.max_students,
          teacher_ids: Orm::TeacherClassroom.where(classroom_id: record.id).pluck(:teacher_id),
          active_students_count: Orm::ClassroomStudent.where(classroom_id: record.id, left_at: nil).count
        )
      end
    end
  end
end
