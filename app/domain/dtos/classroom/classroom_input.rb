# 🧠 DOMAINE · Dtos::Classroom::ClassroomInput
# Rôle : création d'une classe par l'équipe : établissement, niveau et série par slugs, nom (15), plafond (1 à 150, 80)
# ADR  : 0026, 0030, 0041 · UDR : 0031
module Dtos
  module Classroom
    class ClassroomInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      CLASSROOM = Entities::Classroom::Classroom

      attribute :school_public_id, :string
      attribute :level_slug, :string
      attribute :series_slug, :string
      attribute :name, :string
      attribute :max_students, :integer, default: CLASSROOM::MAX_STUDENTS

      validates :school_public_id, :level_slug, presence: true
      validates :name, presence: true, length: { maximum: CLASSROOM::NAME_MAX }
      validates :max_students, numericality: { only_integer: true, in: 1..CLASSROOM::MAX_STUDENTS_LIMIT }

      # Aucun titleize : le nom garde la casse saisie.
      def name
        super.to_s.squish
      end

      def level_slug
        super.to_s.strip.presence
      end

      def series_slug
        super.to_s.strip.presence
      end

      # Niveau, série et établissement restent à part : le use case les résout avant de construire l'entité.
      def to_h = { name:, max_students: }
    end
  end
end
