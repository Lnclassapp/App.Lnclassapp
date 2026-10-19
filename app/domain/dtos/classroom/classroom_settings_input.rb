# 🧠 DOMAINE · Dtos::Classroom::ClassroomSettingsInput
# Rôle : « Modifier la classe » : la fin du nom (le préfixe du barème est fixe) et le plafond (1 à 150)
# ADR  : 0041, 0098 · UDR : 0110
module Dtos
  module Classroom
    class ClassroomSettingsInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      CLASSROOM = Entities::Classroom::Classroom

      attribute :suffix, :string
      attribute :max_students, :integer

      validates :suffix, presence: true
      # La longueur du nom complet dépend du préfixe : le use case la juge (suffix: [:too_long]).
      validates :max_students, numericality: { only_integer: true, in: 1..CLASSROOM::MAX_STUDENTS_LIMIT }

      def suffix
        super.to_s.squish
      end
    end
  end
end
