# 🔌 INFRA · Repositories::Catalog::RepositoryLessonSource
# Rôle : lit les leçons au format 3 de docs/contenus/lecons-traitees/<niveau>/<matière>/*.json, avec leur dossier de niveau et leurs sujets
# ADR  : chargement-automatique-des-lecons-hors-production, 0123
module Repositories
  module Catalog
    class RepositoryLessonSource
      include Ports::Catalog::LessonSourcePort

      PREFIX = "chargement-automatique"

      def initialize(root: Rails.root.join("docs/contenus/lecons-traitees"), logger: Rails.logger)
        @root = root
        @logger = logger
      end

      def lessons
        @root.glob("*/*/*.json").sort.filter_map do |path|
          content = path.read
          course = v3_course(content, path)
          next unless course

          LessonFile.new(import_name: import_name(path), checksum_sha256: Digest::SHA256.hexdigest(content), content:,
                         level_directory: path.parent.parent.basename.to_s, subjects: course["subjects"].present?)
        end
      end

      private

      # Le premier cours d'un fichier au format 3, nil sinon. Un fichier illisible ou d'un autre format n'est pas une leçon à charger : les
      # autres restent chargées.
      def v3_course(content, path)
        document = JSON.parse(content)
        return unless document.is_a?(Hash) && document["version"] == Entities::Catalog::ImportKind::COURSE_TREE_VERSION

        course = Array(document["courses"]).first
        course if course.is_a?(Hash)
      rescue JSON::ParserError
        @logger.warn("[contenus] fichier de leçon illisible, ignoré : #{path}")
        nil
      end

      def import_name(path) = "#{PREFIX}-#{path.parent.parent.basename}-#{path.parent.basename}-#{path.basename}"
    end
  end
end
