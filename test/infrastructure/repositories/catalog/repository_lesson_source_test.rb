require "test_helper"

module Repositories
  module Catalog
    # La source des leçons du dépôt : seules les leçons au format 3 qui portent des sujets de devoir.
    class RepositoryLessonSourceTest < ActiveSupport::TestCase
      setup do
        @root = Pathname(Dir.mktmpdir)
        @warnings = []
        warnings = @warnings
        @logger = Object.new.tap { |logger| logger.define_singleton_method(:warn) { |message| warnings << message } }
      end
      teardown { FileUtils.remove_entry(@root) }

      def write(path, content)
        @root.join(path).tap { it.dirname.mkpath }.write(content.is_a?(String) ? content : JSON.generate(content))
      end

      def lesson(subjects:, version: 3) = { "format" => "lnclass.course-tree", "version" => version, "courses" => [ { "name" => "L", "subjects" => subjects } ] }

      test "keeps the version 3 lessons with subjects, named after their level and subject folders, with the file's own checksum" do
        raw = JSON.pretty_generate(lesson(subjects: [ { "title" => "S" } ]))
        write("3eme/mathematiques/thales.json", raw)

        found = RepositoryLessonSource.new(root: @root, logger: @logger).lessons

        assert_equal [ "chargement-automatique-3eme-mathematiques-thales.json" ], found.map(&:import_name)
        assert_equal [ Digest::SHA256.hexdigest(raw) ], found.map(&:checksum_sha256)
        assert_equal [ raw ], found.map(&:content)
      end

      test "ignores a lesson without subjects, a lesson of another version, an unreadable file and an odd shape" do
        write("3eme/mathematiques/sans-sujet.json", lesson(subjects: []))
        write("3eme/mathematiques/sans-cle.json", { "version" => 3, "courses" => [ { "name" => "L" } ] })
        write("3eme/mathematiques/ancienne.json", lesson(subjects: [ { "title" => "S" } ], version: 2))
        write("3eme/mathematiques/cassee.json", "{ pas du json")
        write("3eme/mathematiques/liste.json", "[]")
        write("3eme/mathematiques/cours-vide.json", { "version" => 3, "courses" => [] })
        write("3eme/mathematiques/cours-texte.json", { "version" => 3, "courses" => [ "x" ] })
        write("3eme/direct.json", lesson(subjects: [ { "title" => "S" } ]))

        assert_empty RepositoryLessonSource.new(root: @root, logger: @logger).lessons
        assert_equal [ "[contenus] fichier de leçon illisible, ignoré : #{@root.join('3eme/mathematiques/cassee.json')}" ], @warnings
      end

      test "lists the lessons in a stable order" do
        %w[b a].each { write("3eme/mathematiques/#{it}.json", lesson(subjects: [ { "title" => "S" } ])) }
        write("2nde/mathematiques/c.json", lesson(subjects: [ { "title" => "S" } ]))

        assert_equal %w[2nde-mathematiques-c 3eme-mathematiques-a 3eme-mathematiques-b],
                     RepositoryLessonSource.new(root: @root).lessons.map { it.import_name.delete_prefix("chargement-automatique-").delete_suffix(".json") }
      end

      test "the repository's own lessons include Thalès" do
        assert_includes RepositoryLessonSource.new.lessons.map(&:import_name),
                        "chargement-automatique-3eme-mathematiques-proprietes-de-thales-dans-un-triangle.json"
      end
    end
  end
end
