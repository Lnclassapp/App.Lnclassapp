# 🧠 DOMAINE · Entities::Assessment::Exercise
# Rôle : un exercice d'une leçon (de notion ou de toute la leçon), son sujet, ses questions et les faits de publication de ses parents
# ADR  : 0035, 0036, 0054, 0105, XXXX-exercice-de-lecon-avec-sujet-et-notion-sans-page
module Entities
  module Assessment
    class Exercise
      include ActiveModel::Model

      TYPES = %w[fixation evaluation].freeze
      TITLE_MAX = 150

      attr_accessor :id, :public_id, :course_id, :essential_id, :exercise_type, :position, :author_id, :status,
                    :published_at, :archived_at, :parents_published
      attr_writer :questions
      attr_reader :title, :statement

      validates :title, presence: true, length: { maximum: TITLE_MAX }
      validates :course_id, presence: true
      validates :exercise_type, inclusion: { in: TYPES }
      validates :status, inclusion: { in: Entities::Shared::ContentStatus::VALUES }

      def title=(value)
        @title = value&.squish
      end

      def statement=(value)
        @statement = value&.strip.presence
      end

      # essential_id nil : exercice de toute la leçon.
      def lesson_wide? = essential_id.nil?
      def questions = @questions || []
      def published? = status == "published"
      def readable_chain_published? = published? && parents_published == true

      # Au moins une question, toutes bien construites (ADR-0035).
      def publishable? = questions.any? && questions.all? { |question| question.structure_errors.empty? }

      # Les questions dont l'image manque ou n'a pas de texte de remplacement, par numéro (ADR-0105 §4.4) → { 2 => [:image_missing] }.
      def image_errors = questions.each_with_index.to_h { |question, index| [ index + 1, question.image_errors ] }.reject { _2.empty? }

      # Une question tentée ne se modifie plus (ADR-0036, ADR-0054).
      def questions_locked?(has_attempts:) = has_attempts
    end
  end
end
