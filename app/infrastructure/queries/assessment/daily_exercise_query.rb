# 🔌 INFRA · Queries::Assessment::DailyExerciseQuery
# Rôle : exercice du jour d'un élève sans travail donné, calculé à la lecture (état, exercice, matière, matière de demain)
# ADR  : 0089 (§4.1) · contrat gelé au Lot 0 du chantier accueil-eleve, implémenté au Lot C
module Queries
  module Assessment
    class DailyExerciseQuery
      # state : :proposed, :done_today ou :none (les autres champs sont alors nil) ; tomorrow_material_name : rempli
      # pour :done_today.
      Row = Data.define(:state, :exercise_public_id, :exercise_title, :material_name, :material_category,
                        :tomorrow_material_name)

      # today : date d'Abidjan, passée par l'appelant ; jamais Date.today (fuseau du serveur).
      def call(student_id:, today: Time.zone.today)
        raise NotImplementedError, "#{self.class.name}#call (student_id: #{student_id}, today: #{today}) : Lot C du chantier accueil-eleve"
      end
    end
  end
end
