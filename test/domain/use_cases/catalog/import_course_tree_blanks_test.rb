require "test_helper"

# CA-13, ADR questions à plusieurs cases §4 : une question « fill_blank » à 3 « ___ » avec des réponses pour les cases 0, 1 et 2
# s'importe ; une case sans réponse, un nombre de « ___ » différent du nombre de cases, ou `blank` > 0 sur un type à une case est
# refusé, avec le chemin de la question et la raison.
module UseCases
  module Catalog
    class ImportCourseTreeBlanksTest < ActiveSupport::TestCase
      setup { seed_referential }

      def subject
        ImportCourseTree.new(courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
                             taxonomy: Repositories::Catalog::TaxonomyRepository.new, writer: Repositories::Catalog::ContentTreeWriter.new)
      end

      def errors_for(question_changes)
        lesson = revision_sheet_document.fetch("courses").first
        question = lesson["notions"][0]["exercise"]["questions"][0]
        question.merge!(question_changes)
        item = subject.validate_root(root: lesson, path: "courses[0]", context: subject.prepare(target: nil))
        item.errors.map { |error| [ error.path, error.params[:rule] ] }
      end

      def blank_answers(*cases) = cases.each_with_index.flat_map { |texts, blank| texts.map { |text| { "content" => text, "correct" => true, "blank" => blank } } }

      PATH = "courses[0].notions[0].exercise.questions[0]".freeze

      test "une question fill_blank à 3 cases, chacune avec ses réponses, est acceptée" do
        assert_empty errors_for("question_type" => "fill_blank", "content" => "___ , ___ et ___", "answers" => blank_answers(%w[a], %w[b c], %w[d]))
      end

      test "une case sans réponse acceptée est refusée avec le chemin de la question et la raison" do
        # Les cases 0 et 2 ont leurs réponses, la case 1 n'en a aucune.
        answers = [ { "content" => "a", "correct" => true, "blank" => 0 }, { "content" => "c", "correct" => true, "blank" => 2 } ]
        found = errors_for("question_type" => "fill_blank", "content" => "___ , ___ et ___", "answers" => answers)

        assert_equal [ [ "#{PATH}.answers", :blank_without_answer ] ], found
      end

      test "un nombre de ___ différent du nombre de cases est refusé" do
        assert_equal [ [ "#{PATH}.answers", :blank_markers_mismatch ] ],
                     errors_for("question_type" => "fill_blank", "content" => "___ et ___", "answers" => blank_answers(%w[a], %w[b], %w[c]))
      end

      test "blank > 0 sur un type à une seule case est refusé" do
        found = errors_for("question_type" => "single_choice", "content" => "Q ?", "answers" => [ { "content" => "a", "correct" => true, "blank" => 1 }, { "content" => "b", "correct" => false } ])

        assert_includes found, [ "#{PATH}.answers", :blank_not_allowed ]
      end
    end
  end
end
