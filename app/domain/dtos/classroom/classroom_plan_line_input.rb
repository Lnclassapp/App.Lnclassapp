# 🧠 DOMAINE · Dtos::Classroom::ClassroomPlanLineInput
# Rôle : les deux nombres d'une ligne du barème saisis par l'équipe, entiers de 0 à 30, gardés tels que saisis
# ADR  : 0026, 0058
module Dtos
  module Classroom
    class ClassroomPlanLineInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      COUNTS = Entities::Classroom::ClassroomPlan::COUNTS

      # Gardés tels que saisis : un texte ne devient pas zéro, et la modale en 422 le réaffiche.
      attribute :public_count, :string
      attribute :private_count, :string

      validates :public_count, :private_count, presence: true
      validates :public_count, :private_count, numericality: { only_integer: true, greater_than_or_equal_to: COUNTS.min,
                                                               less_than_or_equal_to: COUNTS.max }, allow_blank: true

      # Méthodes sur plusieurs lignes, pas en une ligne (`def x = …`) : chargé d'avance (CI, eager_load), un fichier dont
      # aucune ligne ne s'exécute dans les processus de test est pris par SimpleCov pour un fichier jamais chargé, et ses
      # branches y sont ignorées à la fusion (journal du chantier bareme-classes).
      def public_count
        super&.strip
      end

      def private_count
        super&.strip
      end

      # counts : { "public" => Integer | nil, "private" => … }, les nombres actuels d'une ligne.
      def self.from_counts(counts)
        new(public_count: counts["public"]&.to_s, private_count: counts["private"]&.to_s)
      end

      # Appelé sur une saisie valide. → { "public" => Integer, "private" => Integer }
      def counts
        { "public" => Integer(public_count, 10), "private" => Integer(private_count, 10) }
      end
    end
  end
end
