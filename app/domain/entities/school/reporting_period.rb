# 🧠 DOMAINE · Entities::School::ReportingPeriod
# Rôle : période des indicateurs de flux du pilotage : 7 jours, 30 jours ou l'année scolaire, aujourd'hui compris
# ADR  : 0041, 0062
module Entities
  module School
    ReportingPeriod = Data.define(:key, :since) do
      # Une clé absente ou inconnue (paramètre d'URL) vaut la période par défaut.
      def self.parse(key, today:)
        key = self::DEFAULT unless self::KEYS.include?(key)
        since = self::DAYS.key?(key) ? today - (self::DAYS.fetch(key) - 1) : school_year_start(today)
        new(key:, since:)
      end

      def self.school_year_start(today)
        Date.new(Entities::Classroom::SchoolYear.current(today).to_i, Entities::Classroom::SchoolYear::START_MONTH, 1)
      end

      def default? = key == self.class::DEFAULT
    end
    ReportingPeriod::DAYS = { "7d" => 7, "30d" => 30 }.freeze
    ReportingPeriod::KEYS = [ *ReportingPeriod::DAYS.keys, "year" ].freeze
    ReportingPeriod::DEFAULT = "7d"
  end
end
