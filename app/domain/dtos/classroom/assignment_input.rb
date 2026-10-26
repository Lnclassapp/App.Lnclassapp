# 🧠 DOMAINE · Dtos::Classroom::AssignmentInput
# Rôle : ressource à assigner à une classe (type, clé) ; et, à la première assignation, les jours de séance (un au moins)
# ADR  : 0026, 0029, 0048, 0072 · UDR : 0062, 0134 (§3.13 : « Plus tard » est retiré)
module Dtos
  module Classroom
    class AssignmentInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :classroom_public_id, :string
      attribute :assignable_type, :string
      # Slug d'un cours ou d'une fiche essentielle, public_id d'un exercice (ADR-0029).
      attribute :assignable_key, :string

      validates :classroom_public_id, :assignable_key, presence: true
      validates :assignable_type, inclusion: { in: Entities::Classroom::Assignable::TYPES }
      validate :weekdays_answered

      def assignable_key = super.to_s.strip

      # Les cases de la modale des jours (assignment[weekdays][]) ; absentes quand la modale n'a pas été montrée.
      def weekdays=(value)
        @weekdays_given = !value.nil?
        @weekdays = SessionDaysInput.read_weekdays(value) if @weekdays_given
      end

      # → nil (étape des jours non remplie) | [Integer] (jours cochés, triés).
      attr_reader :weekdays

      private

      # « Assigner » dans la modale exige au moins un jour.
      def weekdays_answered
        return unless @weekdays_given
        return errors.add(:weekdays, :inclusion) if @weekdays.nil?

        errors.add(:weekdays, :blank) if @weekdays.empty?
      end
    end
  end
end
