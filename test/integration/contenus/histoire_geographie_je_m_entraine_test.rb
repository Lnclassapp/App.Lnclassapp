require "test_helper"

# Chantier je-m-entraine-dans-la-fiche, contenu d'histoire-géographie : chaque notion des 10 leçons d'histoire-géographie de 3e porte son entraînement (`practice`), distinct de son exercice noté.
module Contenus
  class HistoireGeographieJeMEntraineTest < ActiveSupport::TestCase
    ROOT = Rails.root.join("docs/contenus/lecons-traitees/3eme/histoire-geographie")
    LESSONS = Dir[ROOT.join("*.json")].map { File.basename(it, ".json") }.sort.freeze
    SCHEMA = JSONSchemer.schema(Rails.root.join("config/schemas/lnclass.course-tree.v3.json").read)

    def document(slug) = JSON.parse(ROOT.join("#{slug}.json").read)
    def notions(slug) = document(slug).fetch("courses").first.fetch("notions")
    def multi_blank?(question) = question["answers"].any? { (it["blank"] || 0) > 0 }
    def squish(text) = text.to_s.gsub(/\s+/, " ").strip

    test "les 10 leçons d'histoire-géographie de 3e sont couvertes" do
      assert_equal 10, LESSONS.size
    end

    LESSONS.each do |slug|
      test "#{slug} : le fichier passe le schéma v3" do
        assert_empty SCHEMA.validate(document(slug)).map { "#{it['data_pointer']} #{it['error']}" }.first(5)
      end

      test "#{slug} : chaque notion a un entraînement de 1 à 6 questions, bien formé" do
        notions(slug).each do |notion|
          practice = notion["practice"]
          assert_kind_of Hash, practice, "#{notion['name']} : pas d'entraînement"
          assert_includes 1..6, practice["questions"].size, notion["name"]
          assert_empty Entities::Catalog::NotionPractice.errors_for(practice), notion["name"]
        end
      end

      test "#{slug} : au moins une question à plusieurs cases et un indice" do
        questions = notions(slug).flat_map { it["practice"]["questions"] }
        assert questions.any? { multi_blank?(it) }, "aucune question à plusieurs cases"
        assert questions.any? { it["hint"].present? }, "aucun indice"
      end

      test "#{slug} : une question rédigée au plus" do
        questions = notions(slug).flat_map { it["practice"]["questions"] }
        assert_operator questions.count { it["question_type"] == "written" }, :<=, 1
      end

      test "#{slug} : aucune question d'entraînement n'est celle de l'exercice noté de la notion" do
        notions(slug).each do |notion|
          graded = notion["exercise"]["questions"].map { squish(it["content"]) }
          practiced = notion["practice"]["questions"].map { squish(it["content"]) }
          assert_empty graded & practiced, notion["name"]
        end
      end
    end
  end
end
