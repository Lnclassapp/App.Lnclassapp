# 🧠 DOMAINE · Dtos::Classroom::SessionDaysInput
# Rôle : jours de séance cochés par l'enseignant pour une classe (1 = lundi … 6 = samedi) ; aucun = non renseigné
# ADR  : 0026, 0072 · UDR : 0062
module Dtos
  module Classroom
    class SessionDaysInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :classroom_public_id, :string

      validates :classroom_public_id, presence: true
      validate :weekdays_in_range

      # Cases à cocher (…[weekdays][], champ caché vide compris) → [Integer] triés et dédoublonnés ; nil si une valeur
      # n'est pas un jour de 1 (lundi) à 6 (samedi). Partagé avec AssignmentInput.
      def self.read_weekdays(value)
        days = Array(value).map { it.to_s.strip }.reject(&:empty?).map { Integer(it, 10, exception: false) }
        days.uniq.sort if days.all? { Entities::Classroom::SessionDays::WEEKDAYS.cover?(it) }
      end

      def weekdays=(value)
        @weekdays = self.class.read_weekdays(value)
        @weekdays_invalid = @weekdays.nil?
      end

      # → [Integer] ; [] = non renseigné.
      def weekdays = @weekdays || []

      private

      def weekdays_in_range
        errors.add(:weekdays, :inclusion) if @weekdays_invalid
      end
    end
  end
end
