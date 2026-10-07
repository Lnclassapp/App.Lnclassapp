# 🧠 DOMAINE · Entities::Classroom::SessionDays
# Rôle : jours de la semaine où un enseignant voit une classe ; donne l'échéance d'une assignation
# ADR  : 0072
module Entities
  module Classroom
    SessionDays = Data.define(:weekdays) do
      def initialize(weekdays:)
        days = Array(weekdays).map { Integer(it) }.uniq.sort
        raise ArgumentError, "jour de séance hors de 1..6 : #{days.inspect}" unless days.all? { SessionDays::WEEKDAYS.cover?(it) }

        super(weekdays: days.freeze)
      end

      def none? = weekdays.empty?

      # Le prochain jour de séance strictement après `date` (jamais le jour même), ou nil sans jours.
      def next_after(date)
        (1..7).map { date + it }.find { weekdays.include?(it.cwday) } unless none?
      end
    end
    SessionDays::WEEKDAYS = (1..6) # lundi … samedi (Date#cwday)
  end
end
