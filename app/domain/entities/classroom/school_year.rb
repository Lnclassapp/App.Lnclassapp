# 🧠 DOMAINE · Entities::Classroom::SchoolYear
# Rôle : année scolaire ivoirienne (septembre → août) d'une date
# ADR  : 0041
module Entities
  module Classroom
    module SchoolYear
      START_MONTH = 9
      FORMAT = /\A(\d{4})-(\d{4})\z/

      def self.current(date)
        first = date.month >= START_MONTH ? date.year : date.year - 1
        "#{first}-#{first + 1}"
      end

      # « AAAA-AAAA », la seconde année suivant la première, comme le CHECK de la table.
      def self.valid?(value)
        match = FORMAT.match(value.to_s)
        match.present? && match[2].to_i == match[1].to_i + 1
      end
    end
  end
end
