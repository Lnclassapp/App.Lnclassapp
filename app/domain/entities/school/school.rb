# 🧠 DOMAINE · Entities::School::School
# Rôle : établissement d'une DRENA ; son type choisit le barème des classes, son cycle les niveaux
# ADR  : 0030, 0036, 0037, 0039, 0057, 0063
module Entities
  module School
    class School
      include ActiveModel::Model

      SCHOOL_TYPES = %w[public private mixed].freeze
      CYCLES = %w[first both].freeze
      STATUSES = %w[draft active inactive].freeze
      NAME_MAX = 150
      SIGLE_MAX = 20 # plan.md et db/schema.rb : string(20)

      attr_accessor :id, :public_id, :drena_id, :school_type, :cycle, :school_code, :national_code
      attr_writer :status
      attr_reader :name, :sigle

      validates :name, presence: true, length: { maximum: NAME_MAX }
      validates :sigle, length: { maximum: SIGLE_MAX }
      validates :drena_id, presence: true
      validates :school_type, inclusion: { in: SCHOOL_TYPES }
      validates :cycle, inclusion: { in: CYCLES }
      validates :status, inclusion: { in: STATUSES }

      def status = @status || "active"

      def name=(value)
        @name = value&.squish
      end

      def sigle=(value)
        @sigle = value&.squish.presence
      end

      # Un établissement mixte suit le barème du privé (ADR-0030).
      def plan_type
        school_type == "public" ? "public" : "private"
      end

      def first_cycle_only? = cycle == "first"
      def active? = status == "active"
    end
  end
end
