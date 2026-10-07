# 🧠 DOMAINE · Entities::Classroom::Classroom
# Rôle : une classe d'une école pour une année scolaire, avec ses enseignants et son effectif actif
# ADR  : 0030, 0041, 0083
module Entities
  module Classroom
    class Classroom
      include ActiveModel::Model

      STATUSES = %w[active archived].freeze
      NAME_MAX = 15
      MAX_STUDENTS = 80
      MAX_STUDENTS_LIMIT = 150

      attr_accessor :id, :public_id, :school_id, :level_id, :series_id, :school_year, :join_code, :link_token
      attr_writer :status, :max_students, :teacher_ids, :active_students_count
      attr_reader :name

      validates :name, presence: true, length: { maximum: NAME_MAX }
      validates :school_id, :level_id, presence: true
      validates :status, inclusion: { in: STATUSES }
      validates :max_students, numericality: { only_integer: true, in: 1..MAX_STUDENTS_LIMIT }
      validate :school_year_format

      def name=(value)
        @name = value&.squish
      end

      def status = @status || "active"
      def max_students = @max_students || MAX_STUDENTS
      def teacher_ids = @teacher_ids || []
      def active_students_count = @active_students_count || 0

      def active? = status == "active"
      def full? = active_students_count >= max_students

      private

      def school_year_format
        errors.add(:school_year, :invalid) unless SchoolYear.valid?(school_year)
      end
    end
  end
end
