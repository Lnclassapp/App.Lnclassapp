# 🧠 DOMAINE · Entities::Assessment::RemediationPick
# Rôle : l'exercice proposé pour lever une fiche à revoir : un autre que le raté, de fixation de préférence
# ADR  : 0043, 0101
module Entities
  module Assessment
    module RemediationPick
      # exercises : exercices publiés de la fiche, rangés par (position, id), répondant à id et exercise_type.
      # → l'exercice retenu, ou nil sans exercice.
      def self.call(exercises:, source_exercise_id:)
        others = exercises.reject { it.id == source_exercise_id }
        others.find { it.exercise_type == "fixation" } || others.first || exercises.find { it.id == source_exercise_id }
      end
    end
  end
end
