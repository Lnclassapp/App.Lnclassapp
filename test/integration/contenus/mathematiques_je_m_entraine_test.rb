require "test_helper"

# Chantier je-m-entraine-dans-la-fiche : chaque notion des 10 leçons de mathématiques de 3e porte son entraînement (`practice`),
# distinct de son exercice noté, et chaque valeur chiffrée attendue est recalculée ici (COMPUTED).
module Contenus
  class MathematiquesJeMEntraineTest < ActiveSupport::TestCase
    ROOT = Rails.root.join("docs/contenus/lecons-traitees/3eme/mathematiques")
    LESSONS = ROOT.glob("*.json").map { it.basename(".json").to_s }.sort.freeze
    SCHEMA = JSONSchemer.schema(Rails.root.join("config/schemas/lnclass.course-tree.v3.json").read)
    FORBIDDEN_KEYS = %w[points image criteria].freeze

    # La valeur de chaque case d'une question chiffrée, refaite par le calcul : leçon => { [notion, question] => [case 0, case 1…] }.
    COMPUTED = {
      "proprietes-de-thales-dans-un-triangle" => {
        [ 0, 1 ] => [ 6.0 * 12 / 9, 6.0 * 15 / 9 ],
        [ 0, 2 ] => [ 12.0 * 5 / 15 ],
        [ 1, 0 ] => [ 3.0 / 12, 5.0 / 20 ],
        [ 2, 0 ] => [ 3 * 5, 7 * 2 ]
      },
      "angles-inscrits" => {
        [ 1, 0 ] => [ 84.0 / 2, 2.0 * 29 ],
        [ 1, 2 ] => [ (2.0 * 27 - 0) / (4 - 2) ],
        [ 2, 0 ] => [ 64.0 ],
        [ 2, 2 ] => [ (30.0 + 10) / (4 - 2) ],
        [ 2, 3 ] => [ (360.0 - 2 * 70) / 2 ],
        [ 3, 0 ] => [ Math.sqrt((2 * 7.5)**2 - 9.0**2) ],
        [ 3, 1 ] => [ 90.0, 180.0 - 90 - 50 ]
      },
      "calcul-litteral" => {
        [ 0, 0 ] => [ 3.0 * 1, 3.0 * -5 + 2.0 * 1, 2.0 * -5 ],
        [ 0, 2 ] => [ -4.0 * 2, -4.0 * -5 ],
        [ 1, 0 ] => [ 3.0**2, 2.0 * 3 * 4, 4.0**2 ],
        [ 1, 2 ] => [ 5.0**2, -(2.0**2) ],
        [ 1, 3 ] => [ (50.0 - 1)**2 ],
        [ 2, 0 ] => [ 8.0 / 2, 4.0 / 2, 12.0 / 4 ],
        [ 2, 2 ] => [ 9.0, 9.0 / 9 ],
        [ 2, 3 ] => [ 2.0 + 1, 1.0 + 4 ],
        [ 3, 1 ] => [ Math.sqrt(9), Math.sqrt(4) ],
        [ 3, 2 ] => [ Math.sqrt(81), Math.sqrt(81) ],
        [ 3, 3 ] => [ (51.0 - 49) * (51 + 49) ]
      },
      "calcul-numerique" => {
        [ 0, 0 ] => [ 7.0 * 2, 4 + -1 ],
        [ 0, 1 ] => [ 6.0 - -4 ],
        [ 0, 2 ] => [ 3.0 * 4 ],
        [ 1, 0 ] => [ 7_420_000 / 10.0**6, Math.log10(7_420_000).floor.to_f ],
        [ 1, 1 ] => [ 0.00058 / 10.0**-4, Math.log10(0.00058).floor.to_f ],
        [ 1, 2 ] => [ 23.5 / 10, 2.0 + 1 ],
        [ 2, 0 ] => [ (3.8274 * 100).floor / 100.0, (3.8274 * 100).floor / 100.0 + 0.01 ],
        [ 2, 1 ] => [ (6.7451 * 100).round / 100.0 ],
        [ 2, 3 ] => [ 2.57 - 2.56 ],
        [ 3, 0 ] => [ (730_000 / 10.0**5).round.to_f, Math.log10(730_000).floor.to_f ],
        [ 3, 1 ] => [ 4.0 * 2 * 10**(-3 + 3) ],
        [ 3, 3 ] => [ 4.0e6 / 2.0e3 ]
      },
      "equations-et-inequations-dans-r" => {
        [ 0, 0 ] => [ (25.0 - 4) / 7 ],
        [ 0, 1 ] => [ 3.0 - 4, -7.0 - 1 ],
        [ 0, 3 ] => [ (20.0 + 5) / (9 - 4) ],
        [ 1, 0 ] => [ -7.0, 12.0 / 3 ],
        [ 1, 1 ] => [ 0.0, 10.0 ],
        [ 1, 2 ] => [ 2.0, 5.0 / 2 ],
        [ 2, 1 ] => [ (16.0 - 4) / -3 ],
        [ 2, 3 ] => [ ((-7.0 - 3) / -2).floor + 1 ],
        [ 3, 1 ] => [ (3000.0 - 500) / 250 ],
        [ 3, 2 ] => [ (12000.0 / 1100).floor.to_f ],
        [ 3, 3 ] => [ (36.0 - 45) / (1 - 4), 45.0 + (36.0 - 45) / (1 - 4) ]
      },
      "pyramides-et-cones" => {
        [ 0, 1 ] => [ 81.0 * 10 / 3 ],
        [ 0, 2 ] => [ 6.0 * 6 * 5 / 3, 6.0 * 6 * 7 / 3 ],
        [ 1, 0 ] => [ 10.0 / 2 ],
        [ 1, 1 ] => [ 5.0**2 * 9 / 3 ],
        [ 1, 2 ] => [ 5.0**2 * 9 / 3 * 3.14 ],
        [ 1, 3 ] => [ 3.0**2 * 6 / 3, 6.0**2 * 3 / 3 ],
        [ 2, 1 ] => [ Math.sqrt(8.0**2 + 15**2) ],
        [ 2, 2 ] => [ 8.0 * Math.sqrt(8.0**2 + 15**2) ],
        [ 2, 3 ] => [ 12.0 * Math.sqrt(12.0**2 + 5**2), 15.0 * Math.sqrt(15.0**2 + 8**2) ],
        [ 3, 1 ] => [ Math.sqrt(15.0**2 + 8**2) ],
        [ 3, 2 ] => [ 4 * 16.0 * Math.sqrt(15.0**2 + 8**2) / 2 ],
        [ 3, 3 ] => [ 6 * 4.0 * 5 / 2, 3 * 4.0 * 5 / 2 ]
      },
      "racines-carrees" => {
        [ 0, 0 ] => [ Math.sqrt(196), Math.sqrt(225) ],
        [ 0, 2 ] => [ Math.sqrt(400) ],
        [ 1, 0 ] => [ Math.sqrt(72 / 2.0), 2.0 ],
        [ 1, 1 ] => [ Math.sqrt(200 / 2.0), 2.0 ],
        [ 2, 0 ] => [ Math.sqrt(45 / 5.0), Math.sqrt(20 / 5.0) ],
        [ 2, 1 ] => [ Math.sqrt(45 / 5.0) + Math.sqrt(20 / 5.0) - 1 ],
        [ 3, 0 ] => [ Math.sqrt(2 * 8), Math.sqrt(45 / 5.0) ],
        [ 3, 1 ] => [ 2 * 5 * Math.sqrt(3 * 6) / Math.sqrt(2), 2.0 ],
        [ 4, 0 ] => [ 8 / Math.sqrt(2) / Math.sqrt(2), 9 / Math.sqrt(3) / Math.sqrt(3) ],
        [ 4, 2 ] => [ 12 / (3 * Math.sqrt(2)) / Math.sqrt(2), 2.0 ],
        [ 5, 0 ] => [ (4 * Math.sqrt(3))**2, 7.0**2 ]
      },
      "statistique" => {
        [ 0, 0 ] => [ 50.0 - (5 + 20 + 15) ],
        [ 0, 1 ] => [ 5.0 / 50 * 100, 20.0 / 50 * 100, 15.0 / 50 * 100 ],
        [ 1, 0 ] => [ 1.0 * 4, 2.0 * 3, 4.0 * 1 ],
        [ 1, 1 ] => [ (0 * 2 + 1 * 4 + 2 * 3 + 4 * 1).to_f / (2 + 4 + 3 + 1) ],
        [ 1, 2 ] => [ (0.0 + 20) / 2, (20.0 + 40) / 2, (40.0 + 60) / 2 ],
        [ 1, 3 ] => [ (10 * 6 + 30 * 10 + 50 * 4).to_f / (6 + 10 + 4) ],
        [ 2, 1 ] => [ [ 38, 39, 40, 41, 43 ].max.to_f, [ 38, 39, 40, 41, 43 ].min.to_f, ([ 38, 39, 40, 41, 43 ].max - [ 38, 39, 40, 41, 43 ].min).to_f ],
        [ 3, 0 ] => [ [ 11, 4, 16, 9, 13, 7, 12 ].size.to_f, ([ 11, 4, 16, 9, 13, 7, 12 ].size + 1) / 2.0 ],
        [ 3, 1 ] => [ [ 11, 4, 16, 9, 13, 7, 12 ].sort[3].to_f ],
        [ 3, 2 ] => [ [ 5, 15, 9, 12, 8, 10 ].sort[2].to_f, [ 5, 15, 9, 12, 8, 10 ].sort[3].to_f ],
        [ 3, 3 ] => [ ([ 5, 15, 9, 12, 8, 10 ].sort[2] + [ 5, 15, 9, 12, 8, 10 ].sort[3]) / 2.0 ],
        [ 4, 0 ] => [ 90.0 / 200 * 360, 60.0 / 200 * 360, 30.0 / 200 * 360 ],
        [ 4, 1 ] => [ 20.0 / 200 * 360 ]
      },
      "triangle-rectangle" => {
        [ 0, 1 ] => [ 9.0 + 16, Math.sqrt(9.0 * 16) ],
        [ 0, 2 ] => [ Math.sqrt(9.0 * (9 + 16)), Math.sqrt(16.0 * (9 + 16)) ],
        [ 1, 1 ] => [ 0.28 * 25, 0.96 * 25 ],
        [ 2, 1 ] => [ 1 - 0.28**2, Math.sqrt(1 - 0.28**2) ],
        [ 2, 2 ] => [ 0.28 / Math.sqrt(1 - 0.28**2) ],
        [ 3, 1 ] => [ 20 * Math.cos(60 * Math::PI / 180), 20 * Math.sin(60 * Math::PI / 180) ],
        [ 3, 2 ] => [ 9 * Math.tan(45 * Math::PI / 180) ],
        [ 3, 3 ] => [ 7 / Math.sin(30 * Math::PI / 180) ]
      },
      "vecteurs" => {
        [ 0, 0 ] => [ 8.0 - 3, 4.0 - (-2) ],
        [ 0, 2 ] => [ 3.0 - (-1) ],
        [ 1, 0 ] => [ 3.0 - (-1), 3.0 - 2 ],
        [ 1, 1 ] => [ 5.0 - (3.0 - (-1)), 6.0 - (3.0 - 2) ],
        [ 2, 0 ] => [ (1.0 - (-2)) + (4 - 1), (4.0 - 1) + (2 - 4) ],
        [ 2, 2 ] => [ 5.0 + (-3), -2.0 + 6 ],
        [ 3, 0 ] => [ 4.0 * 9, (-6.0) * (-6) ],
        [ 3, 2 ] => [ 5.0 * (-8) / 10 ]
      }
    }.freeze

    def document(slug) = JSON.parse(ROOT.join("#{slug}.json").read)
    def notions(slug) = document(slug).fetch("courses").first.fetch("notions")
    def multi_blank?(question) = question["answers"].any? { (it["blank"] || 0) > 0 }
    def squish(text) = text.to_s.gsub(/\s+/, " ").strip
    def number(text) = Entities::Assessment::QuestionKinds::Numeric.parse(text)

    test "les 10 leçons de mathématiques de 3e sont couvertes" do
      assert_equal 10, LESSONS.size
    end

    LESSONS.each do |slug|
      test "#{slug} : le fichier passe le schéma v3" do
        assert_empty SCHEMA.validate(document(slug)).map { "#{it['data_pointer']} #{it['error']}" }.first(5)
      end

      test "#{slug} : chaque notion a un entraînement de 1 à 6 questions, bien formé, sans clé de copie notée" do
        notions(slug).each do |notion|
          practice = notion["practice"]
          assert_kind_of Hash, practice, "#{notion['name']} : pas d'entraînement"
          assert_predicate practice["statement"].to_s.strip, :present?, notion["name"]
          assert_includes 1..6, practice["questions"].size, notion["name"]
          practice["questions"].each { |question| assert_empty FORBIDDEN_KEYS & question.keys, notion["name"] }
          assert_empty Entities::Catalog::NotionPractice.errors_for(practice), notion["name"]
        end
      end

      test "#{slug} : au moins une question à plusieurs cases et un indice" do
        questions = notions(slug).flat_map { it["practice"]["questions"] }
        assert questions.any? { multi_blank?(it) }, "aucune question à plusieurs cases"
        assert questions.any? { it["hint"].present? }, "aucun indice"
      end

      test "#{slug} : une question à plusieurs cases a autant de ___ que de cases, et une seule bonne réponse chiffrée par case" do
        notions(slug).flat_map { it["practice"]["questions"] }.select { multi_blank?(it) }.each do |question|
          blanks = question["answers"].map { it["blank"] || 0 }.uniq.sort
          assert_equal (0...blanks.size).to_a, blanks, question["content"]
          assert_equal blanks.size, question["content"].scan("___").size, question["content"]
          next unless question["question_type"] == "numeric"

          assert_equal blanks, question["answers"].map { it["blank"] || 0 }.sort, question["content"]
        end
      end

      test "#{slug} : aucune question d'entraînement n'est celle de l'exercice noté de la notion" do
        notions(slug).each do |notion|
          graded = notion["exercise"]["questions"].map { squish(it["content"]) }
          practiced = notion["practice"]["questions"].map { squish(it["content"]) }
          assert_empty graded & practiced, notion["name"]
        end
      end

      test "#{slug} : chaque valeur chiffrée attendue est celle du calcul, à la tolérance près" do
        expected = COMPUTED.fetch(slug, {})
        found = []
        notions(slug).each_with_index do |notion, notion_index|
          notion["practice"]["questions"].each_with_index do |question, question_index|
            next unless question["question_type"] == "numeric"

            key = [ notion_index, question_index ]
            found << key
            values = expected[key]
            refute_nil values, "#{slug} #{key} : valeur non recalculée dans COMPUTED"
            answers = question["answers"].sort_by { it["blank"] || 0 }
            assert_equal values.size, answers.size, "#{slug} #{key} : nombre de cases"
            margin = BigDecimal((question["tolerance"] || 0).to_s) + BigDecimal("1e-9")
            answers.zip(values).each do |answer, value|
              assert (number(answer["content"]) - BigDecimal(value.to_s)).abs <= margin,
                     "#{slug} #{key} : #{answer['content']} attendu, le calcul donne #{value}"
            end
          end
        end
        assert_empty expected.keys - found, "#{slug} : COMPUTED décrit une question chiffrée qui n'existe pas"
      end
    end
  end
end
