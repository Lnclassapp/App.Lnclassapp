# 🔌 INFRA · Repositories::Catalog::RepositoryLessonSource
# Rôle : lit les leçons à sujets de devoir de docs/contenus/lecons-traitees/<niveau>/<matière>/*.json (format 3)
# ADR  : chargement-automatique-des-lecons-hors-production
module Repositories
  module Catalog
    class RepositoryLessonSource
      include Ports::Catalog::LessonSourcePort

      PREFIX = "chargement-automatique"

      def initialize(root: Rails.root.join("docs/contenus/lecons-traitees"))
        @root = root
      end

      def lessons
        @root.glob("*/*/*.json").sort.filter_map do |path|
          content = path.read
          next unless with_subjects?(content)

          LessonFile.new(import_name: import_name(path), checksum_sha256: Digest::SHA256.hexdigest(content), content:)
        end
      end

      private

      # Un fichier illisible ou d'un autre format n'est pas une leçon à charger : les autres restent chargées.
      def with_subjects?(content)
        document = JSON.parse(content)
        return false unless document.is_a?(Hash) && document["version"] == Entities::Catalog::ImportKind::COURSE_TREE_VERSION

        course = Array(document["courses"]).first
        course.is_a?(Hash) && course["subjects"].present?
      rescue JSON::ParserError
        false
      end

      def import_name(path) = "#{PREFIX}-#{path.parent.parent.basename}-#{path.parent.basename}-#{path.basename}"
    end
  end
end
