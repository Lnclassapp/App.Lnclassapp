# 🧠 DOMAINE · Entities::Catalog::CourseSheet
# Rôle : la fiche de cours d'une leçon, un document de blocs sous un des trois thèmes ; une seule par leçon
# ADR  : XXXX-fiche-de-cours-en-donnees-importees (contenu-en-blocs, #318)
module Entities
  module Catalog
    class CourseSheet
      include ActiveModel::Model

      THEMES = %w[blue teal burgundy].freeze
      FORMAT_VERSION = 1

      attr_accessor :id, :course_id, :theme, :document, :format_version, :created_at

      validates :course_id, presence: true
      validates :theme, inclusion: { in: THEMES }
      validates :format_version, inclusion: { in: [ FORMAT_VERSION ] }
      validate :document_is_valid

      def sheet_document = @sheet_document ||= SheetDocument.new(document)

      def document_errors = sheet_document.errors

      def pages = sheet_document.pages

      def glossary = sheet_document.glossary

      private

      def document_is_valid
        document_errors.each { errors.add(:document, it.to_s) }
      end
    end
  end
end
