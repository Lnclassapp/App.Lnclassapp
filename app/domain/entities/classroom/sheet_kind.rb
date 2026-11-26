# 🧠 DOMAINE · Entities::Classroom::SheetKind
# Rôle : interros (1 ou 2 exercices) ou devoirs (3 ou plus) : le seuil partagé par « Ma classe » et les notifications
# ADR  : 0146 · 0121 (§4)
module Entities
  module Classroom
    module SheetKind
      DEVOIRS_FROM = 3

      # → :interros | :devoirs
      def self.for(exercise_count) = exercise_count >= DEVOIRS_FROM ? :devoirs : :interros
    end
  end
end
