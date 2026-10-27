# 🔌 INFRA · Queries::Classroom::JoinCodePreviewQuery
# Rôle : aperçu public d'une classe par son code : nom de la classe, niveau, établissement (sigle ou nom), « complète » ; jamais d'archivée
# ADR  : 0109 (§4) · UDR : 0081
module Queries
  module Classroom
    class JoinCodePreviewQuery
      # Ce que la vérification du code révèle, et rien de plus : ni identifiant, ni effectif, ni enseignant, ni élève, ni jeton.
      CodeRow = Data.define(:classroom_name, :level_name, :school_label, :full)

      COLUMNS = [ "classrooms.name", "levels.name", "schools.sigle", "schools.name", "classrooms.id", "classrooms.max_students" ].freeze

      # La saisie est normalisée ici (casse, espaces, tiret). Un code mal formé ne touche pas la base. Une classe archivée, un
      # établissement qui n'est pas actif et un code inconnu donnent le même nil : la page ne dit pas lequel (CA-B3).
      # → CodeRow | nil
      def code(code:)
        normalized = Entities::Classroom::JoinCode.normalize(code)
        return unless Entities::Classroom::JoinCode.valid?(normalized)

        values = Orm::Classroom.joins(:school, :level)
                               .where(join_code: normalized, status: "active", schools: { status: "active" })
                               .pick(*COLUMNS)
        return unless values

        classroom_name, level_name, sigle, school_name, id, max_students = values
        full = Orm::ClassroomStudent.where(classroom_id: id, left_at: nil).count >= max_students
        CodeRow.new(classroom_name:, level_name:, school_label: sigle.presence || school_name, full:)
      end
    end
  end
end
