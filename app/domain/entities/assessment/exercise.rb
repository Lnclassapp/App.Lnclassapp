# 🧠 DOMAINE · Entities::Assessment::Exercise
# Rôle : un exercice d'une fiche, ses questions, et les faits de publication de ses parents
# ADR  : 0035, 0036, 0054
module Entities
  module Assessment
    class Exercise
      include ActiveModel::Model

      TYPES = %w[fixation evaluation].freeze
      TITLE_MAX = 150

      attr_accessor :id, :public_id, :essential_id, :exercise_type, :position, :author_id, :status,
                    :published_at, :archived_at, :parents_published
      attr_writer :questions
      attr_reader :title, :description

      validates :title, presence: true, length: { maximum: TITLE_MAX }
      validates :essential_id, presence: true
      validates :exercise_type, inclusion: { in: TYPES }
      validates :status, inclusion: { in: Catalog::ContentStatus::VALUES }

      def title=(value)
        @title = value&.squish
      end

      def description=(value)
        @description = value&.strip.presence
      end

      def questions = @questions || []
      def published? = status == "published"
      def readable_chain_published? = published? && parents_published == true

      # Au moins une question, toutes bien construites (ADR-0035).
      def publishable? = questions.any? && questions.all? { |question| question.structure_errors.empty? }

      # Une question tentée ne se modifie plus (ADR-0036, ADR-0054).
      def questions_locked?(has_attempts:) = has_attempts
    end
  end
end
