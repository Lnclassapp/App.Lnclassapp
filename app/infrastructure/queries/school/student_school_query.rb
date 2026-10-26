# 🔌 INFRA · Queries::School::StudentSchoolQuery
# Rôle : « Mon établissement » de l'élève : nom, sigle, DRENA et type de l'établissement de sa classe principale (lecture seule)
# ADR  : 0006 · UDR : écrans élève sans répétition §3.6 bis · student_id : current_actor.user_id, jamais un paramètre
module Queries
  module School
    class StudentSchoolQuery
      # Rien d'autre : ni identifiant, ni code d'établissement, ni jeton de lien, ni effectif. sigle : nil s'il n'y en a pas.
      Row = Data.define(:name, :sigle, :drena_name, :school_type)

      COLUMNS = [ "schools.name", "schools.sigle", "drenas.name", "schools.school_type" ].freeze

      # → Row | nil (aucune classe principale active : l'élève n'a pas d'établissement à montrer)
      def call(student_id:)
        return if student_id.nil?

        values = Orm::ClassroomStudent.joins(classroom: { school: :drena })
                                      .where(student_id:, primary: true, left_at: nil, classrooms: { status: "active" })
                                      .pick(*COLUMNS)
        return if values.nil?

        name, sigle, drena_name, school_type = values
        Row.new(name:, sigle: sigle.presence, drena_name:, school_type:)
      end
    end
  end
end
