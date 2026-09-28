# 🧠 DOMAINE · Entities::Classroom::ClassroomPlan
# Rôle : barème des classes générées, valeur construite de ses entrées ; une entrée absente est « non définie » (nil)
# ADR  : 0030, 0058
module Entities
  module Classroom
    class ClassroomPlan
      # Un établissement mixed suit le barème private (ADR-0030).
      SCHOOL_TYPES = %w[public private].freeze
      COUNTS = 0..30

      # series_id : nil pour un niveau du premier cycle.
      Entry = Data.define(:school_type, :level_id, :series_id, :count)

      attr_reader :entries

      def self.school_type_for(school_type) = school_type == "public" ? "public" : "private"

      def initialize(entries:)
        @entries = entries.dup.freeze
        @counts = entries.to_h { [ [ it.school_type, it.level_id, it.series_id ], it.count ] }.freeze
      end

      # → Integer | nil (ligne non définie)
      def count(school_type:, level_id:, series_id: nil)
        @counts[[ self.class.school_type_for(school_type), level_id, series_id ]]
      end
    end
  end
end
