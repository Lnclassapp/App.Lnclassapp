require "test_helper"

# IM-13, ADR-0068 §4 : l'écriture accélérée des arbres de contenu écrit exactement ce qu'écrivait l'écrivain d'avant.
# Les 4 leçons de Tle D (nœuds d'avant le format 3) passent par ContentTreeWriter#write ; toutes les
# lignes écrites sont comparées, champ par champ, à l'instantané pris AVANT l'optimisation
# (test/fixtures/files/content_tree_snapshot.json). Cet instantané ne se régénère pas : si ce test rougit, c'est
# l'implémentation qu'on corrige.
module Repositories
  module Catalog
    class ContentTreeWriterCharacterizationTest < ActiveSupport::TestCase
      LESSONS = %w[mathematiques/limites-et-continuite physique-chimie/cinematique-du-point physique-chimie/les-alcools
                   svt/le-devenir-des-cellules-sexuelles-chez-les-mammiferes]
                .map { Rails.root.join("docs/contenus/lecons-traitees/tle-d/#{it}.json") }.sort_by { File.basename(it) }
      SNAPSHOT = "content_tree_snapshot.json"
      TABLES = %w[courses essentials exercises questions answers action_text_rich_texts].freeze
      # Identifiants, horodatages de création et auteur : ils changent d'une base à l'autre, pas le contenu.
      IGNORED = %w[id public_id created_at updated_at author_id record_id].freeze
      # ADR-0091 : colonnes venues après l'instantané ; ces leçons n'ont que des choix, elles restent vides (vérifié à part).
      # ADR-0115 : points (1 par défaut), unit, starter, criteria et statement_blocks viennent aussi après l'instantané ; l'import
      # d'aujourd'hui ne les écrit pas encore (Lot D), les lignes gardent leurs valeurs par défaut (vérifié à part).
      # ADR-0116 : figures, sheet_theme, sheet et figure_key (format 3) viennent aussi après lui ; ces nœuds d'avant les laissent à leur défaut.
      ADDED_LATER = %w[numeric_tolerance match_content points unit starter criteria statement_blocks figures sheet_theme sheet figure_key].freeze

      setup do
        seed_referential
        @author = create_team_member(team_role: "content", second_factor: false)
        @before = TABLES.index_with { |table| connection.select_value("SELECT COALESCE(MAX(id), 0) FROM #{table}") }
      end

      def connection = ActiveRecord::Base.connection

      Port = Ports::Catalog::ContentTreeWriterPort

      # Le format 1 n'est plus lu à l'import (ADR-0116) : les nœuds d'avant (fiche à texte riche, exercices des notions) sont bâtis ici
      # depuis les fichiers, comme l'adaptateur d'alors les bâtissait ; c'est l'écriture, pas la lecture, que ce test garde.
      def course_node(root, lookup, taken_courses, taken_essentials)
        name = root["name"].squish
        essentials = root["essentials"].each_with_index.map do |essential, index|
          Port::EssentialNode.new(slug: Entities::Catalog::Slug.unique("#{name} #{essential['name'].squish}", taken: taken_essentials), course_id: nil,
                                  name: essential["name"].squish, subtitle: essential["subtitle"].to_s.squish.presence, content: essential["content"],
                                  position: index + 1, exercises: legacy_exercises(essential))
        end
        series = lookup.resolve_series(root["series_name"])
        Port::CourseNode.new(slug: Entities::Catalog::Slug.unique(name, taken: taken_courses), name:, subtitle: root["subtitle"].to_s.squish.presence,
                             content: root["content"], level_id: lookup.resolve_level(root["level_name"]).id, series_id: series&.id,
                             material_id: lookup.resolve_material(root["material_name"]).id, essentials:)
      end

      # Les 4 leçons sont écrites en un seul lot.
      def import_lessons
        lookup = TaxonomyRepository.new.lookup
        taken_courses = Set.new
        taken_essentials = Set.new
        roots = LESSONS.flat_map { |file| JSON.parse(file.read).fetch("courses") }
        courses = roots.map { |root| course_node(root, lookup, taken_courses, taken_essentials) }
        counts = ContentTreeWriter.new.write(courses:, author_id: @author.id, at: Time.zone.parse("2026-09-30 08:00"))
        { imported: counts.fetch(:courses) }
      end

      def legacy_exercises(essential)
        Array(essential["exercises"]).each_with_index.map do |exercise, index|
          Port::ExerciseNode.new(
            public_id: SecureRandom.base58(14), essential_id: nil, title: (exercise["title"] || exercise["name"]).squish,
            statement: exercise["description"].to_s.strip.presence, exercise_type: exercise["exercise_type"], position: index + 1,
            questions: exercise["questions"].each_with_index.map { |question, rank| Port::QuestionNode.from_import(question, position: rank + 1) }
          )
        end
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
        # ADR-XXXX : la position d'un exercice est unique par leçon et sa description est devenue son sujet ; l'instantané les
        # garde par notion et sous leur ancien nom, et c'est ce que l'on compare ici.
        first_position = created("exercises").group_by { it["essential_id"] }.transform_values { |rows| rows.map { it["position"] }.min - 1 }
        rows = TABLES.to_h do |table|
          lines = created(table).map do |row|
            row = row.merge("position" => row["position"] - first_position.fetch(row["essential_id"]), "description" => row["statement"]).except("statement") if table == "exercises"
            path = path_of(table, row, paths)
            paths[[ table, row["id"] ]] = path
            line = row.except(*IGNORED, *ADDED_LATER, "course_id", "essential_id", "exercise_id", "question_id")
            # ADR-0105 : colonne née après l'instantané ; une leçon sans image l'écrit vide, ce que l'instantané ne connaît pas.
            line.delete("image_description") if line.key?("image_description") && line["image_description"].nil?
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
        assert_equal [ nil ], (created("questions").map { it["numeric_tolerance"] } + created("answers").map { it["match_content"] }).uniq
        assert_equal [ BigDecimal("1"), nil, nil, "{}" ], %w[points unit starter criteria].map { |column| created("questions").map { it[column] }.uniq.sole }
        assert_equal [ nil ], created("exercises").map { it["statement_blocks"] }.uniq
        assert_equal [ [ "[]" ], [ "blue" ], [ {} ], [ nil ] ],
                     [ created("courses").pluck("figures").uniq, created("courses").pluck("sheet_theme").uniq, created("essentials").pluck("sheet").uniq.map { it.is_a?(String) ? JSON.parse(it) : it },
                       created("exercises").pluck("figure_key").uniq ]
        assert_equal 4, written.fetch(:imported)
        assert_equal [ @author.id ], %w[courses essentials exercises].flat_map { |table| created(table).map { it["author_id"] } }.uniq
      end
    end
  end
end
