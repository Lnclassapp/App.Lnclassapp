# 🧠 DOMAINE · Dtos::Classroom::AssignmentInput
# Rôle : ressource à assigner à une classe (type, clé) ; et, à la première assignation, les jours de séance ou « Plus tard »
# ADR  : 0026, 0029, 0048, 0072 · UDR : 0062
module Dtos
  module Classroom
    class AssignmentInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :classroom_public_id, :string
      attribute :assignable_type, :string
      # Slug d'un cours ou d'une fiche essentielle, public_id d'un exercice (ADR-0029).
      attribute :assignable_key, :string
      # « Plus tard » (UDR-0062 §3.4) : assigner sans renseigner les jours ; la question reviendra.
      attribute :later, :boolean, default: false

      validates :classroom_public_id, :assignable_key, presence: true
      validates :assignable_type, inclusion: { in: Entities::Classroom::Assignable::TYPES }
      validate :weekdays_answered

      def assignable_key = super.to_s.strip

      # Les cases de la modale des jours (assignment[weekdays][]) ; absentes quand la modale n'a pas été montrée.
      def weekdays=(value)
        @weekdays_given = !value.nil?
        @weekdays = SessionDaysInput.read_weekdays(value) if @weekdays_given
      end

      # → nil (étape des jours non remplie, ou « Plus tard ») | [Integer] (jours cochés, triés).
      def weekdays = (@weekdays unless later)

      private

      # « Assigner » dans la modale exige au moins un jour ; « Plus tard » n'en demande aucun.
      def weekdays_answered
        return if later || !@weekdays_given
        return errors.add(:weekdays, :inclusion) if @weekdays.nil?

        errors.add(:weekdays, :blank) if @weekdays.empty?
      end
    end
  end
end
