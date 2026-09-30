require "test_helper"

# IM-13, ADR-0068 §4 : l'écriture accélérée des arbres de contenu écrit exactement ce qu'écrivait l'écrivain d'avant.
# Les 4 leçons de Tle D passent par la vraie chaîne (adaptateur ImportCourseTree, puis ContentTreeWriter) ; toutes les
# lignes écrites sont comparées, champ par champ, à l'instantané pris AVANT l'optimisation
# (test/fixtures/files/content_tree_snapshot.json). Cet instantané ne se régénère pas : si ce test rougit, c'est
# l'implémentation qu'on corrige.
module Repositories
  module Catalog
    class ContentTreeWriterCharacterizationTest < ActiveSupport::TestCase
      LESSONS = Rails.root.glob("docs/contenus/lecons-traitees/tle-d/*.json").sort
      SNAPSHOT = "content_tree_snapshot.json"
      TABLES = %w[courses essentials exercises questions answers action_text_rich_texts].freeze
      # Identifiants, horodatages de création et auteur : ils changent d'une base à l'autre, pas le contenu.
      IGNORED = %w[id public_id created_at updated_at author_id record_id].freeze

      setup do
        seed_referential
        @author = create_team_member(team_role: "content", second_factor: false)
        @before = TABLES.index_with { |table| connection.select_value("SELECT COALESCE(MAX(id), 0) FROM #{table}") }
      end

      def connection = ActiveRecord::Base.connection

      def adapter
        UseCases::Catalog::ImportCourseTree.new(
          courses: CourseRepository.new, essentials: EssentialRepository.new, taxonomy: TaxonomyRepository.new, writer: ContentTreeWriter.new
        )
      end

      # Chaque cours est validé comme le moteur le fait, puis les 4 sont écrits en un seul lot.
      def import_lessons
        subject = adapter
        context = subject.prepare(target: nil)
        items = LESSONS.flat_map { |file| JSON.parse(file.read).fetch("courses") }.each_with_index.map do |root, index|
          subject.validate_root(root:, path: "courses[#{index}]", context:).tap { |item| assert item.valid?, item.errors.inspect }
        end
        subject.write(items:, author_id: @author.id, at: Time.zone.parse("2026-09-30 08:00"))
      end

      # Lignes créées par ce test, dans l'ordre des id.
      def created(table)
        connection.select_all("SELECT * FROM #{table} WHERE id > #{@before.fetch(table)} ORDER BY id").to_a
      end

      def names(table) = connection.select_rows("SELECT id, name FROM #{table}").to_h

      # Chaque clé étrangère devient un chemin stable : slug du cours ou de la fiche, puis positions.
      def snapshot
        taxonomy = { "level_id" => names("levels"), "series_id" => names("series"), "material_id" => names("materials") }
        paths = {}
        rows = TABLES.to_h do |table|
          lines = created(table).map do |row|
            path = path_of(table, row, paths)
            paths[[ table, row["id"] ]] = path
            line = row.except(*IGNORED, "course_id", "essential_id", "exercise_id", "question_id")
            taxonomy.each { |column, by_id| line[column] = by_id[row[column]] if row.key?(column) }
            { "path" => path }.merge(line)
          end
          [ table, lines.sort_by { it["path"] } ]
        end
        JSON.parse(JSON.generate(rows))
      end

      def path_of(table, row, paths)
        case table
        when "courses", "essentials" then row["slug"]
        when "exercises" then "#{paths.fetch([ 'essentials', row['essential_id'] ])}/#{row['position']}"
        when "questions" then "#{paths.fetch([ 'exercises', row['exercise_id'] ])}/#{row['position']}"
        when "answers" then "#{paths.fetch([ 'questions', row['question_id'] ])}/#{row['position']}"
        else "#{row['record_type']}:#{paths.fetch([ row['record_type'] == 'Orm::Course' ? 'courses' : 'essentials', row['record_id'] ])}"
        end
      end

      test "les 4 leçons de Tle D écrivent, ligne pour ligne, l'instantané pris avant l'optimisation" do
        assert_equal 4, LESSONS.size

        written = import_lessons

        expected = JSON.parse(file_fixture(SNAPSHOT).read)
        actual = snapshot
        assert_equal expected.transform_values(&:size), actual.transform_values(&:size)
        TABLES.each do |table|
          expected.fetch(table).zip(actual.fetch(table)).each { |want, got| assert_equal want, got, "#{table} #{want['path']}" }
        end
        assert_equal 4, written.fetch(:imported)
        assert_equal [ @author.id ], %w[courses essentials exercises].flat_map { |table| created(table).map { it["author_id"] } }.uniq
      end
    end
  end
end
