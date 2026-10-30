require "test_helper"

module Entities
  module Assessment
    # CA-5 — ADR entraînement corrigé sans trace §7 : une même réponse reçoit le même verdict dans la fiche et dans une copie notée,
    # parce que les deux se jugent avec les règles de Question.
    class PracticeParityTest < ActiveSupport::TestCase
      Notion = Struct.new(:slug, :name, :status, :course_status, :level_id, :series_id, :practice) do
        def readable_chain_published? = true
      end

      class Notions
        include Ports::Catalog::EssentialRepositoryPort

        def initialize(practice) = @notion = Notion.new("n", "N", "published", "published", 1, nil, practice)
        def practice_for(**) = @notion
      end

      Student = Data.define(:role) do
        def student? = true
        def team? = false
      end

      # Ce que fait la copie notée pour un texte saisi : SubmitExerciseCopy refuse une saisie mal formée (erreur de saisie) et corrige le reste.
      def graded_copy_verdict(question, text)
        return :blank if text.strip.empty?

        question.well_formed?(text) && question.correct?(text) ? :correct : :wrong
      end

      def practice_verdict(raw_question, text)
        practice = Catalog::NotionPractice.from_raw(raw_practice(raw_question))
        result = check_practice_with(Notions.new(practice))
                                                 .call(actor: Student.new(role: "student"), audience: Catalog::LevelAudience.new(pairs: [ [ 1, nil ] ]),
                                                       course_slug: "c", notion_slug: "n", digest: practice.digest,
                                                       responses: { "0" => { "blanks" => { "0" => text } } })
        result.value.questions.first.verdicts.first
      end

      def copy_question(raw)
        answers = raw["answers"].each_with_index.map { |a, i| Answer.new(id: i, position: i + 1, content: a["content"], correct: true, blank: a["blank"] || 0) }
        Question.new(id: 1, position: 1, content: raw["content"], explanation: raw["explanation"], question_type: raw["question_type"], answers:,
                     numeric_tolerance: raw["tolerance"]&.then { BigDecimal(it.to_s) }, unit: raw["unit"])
      end

      NUMERIC_INPUTS = [ "4,8", "4.8", "4,8 cm", " 4,81 ", "4,9", "-4,8", "1 000", "abc", "", "4,8 m", "4,8cm" ].freeze
      FILL_INPUTS = [ "hypoténuse", "HYPOTENUSE", "  hypoténuse  ", "hypotenuse ", "hypoténus", "autre", "" ].freeze

      test "CA-5: un chiffré reçoit le même verdict dans la fiche et dans la copie notée" do
        raw = numeric_question
        question = copy_question(raw)

        NUMERIC_INPUTS.each do |input|
          assert_equal graded_copy_verdict(question, input), practice_verdict(raw, input), "saisie #{input.inspect}"
        end
      end

      test "CA-5: un texte à trous reçoit le même verdict dans la fiche et dans la copie notée" do
        raw = fill_blank_question
        question = copy_question(raw)

        FILL_INPUTS.each do |input|
          assert_equal graded_copy_verdict(question, input), practice_verdict(raw, input), "saisie #{input.inspect}"
        end
      end

      # En attente du Lot A : le verdict par case des questions à plusieurs cases est celui de Question#blank_results.
      test "CA-5: une question à plusieurs cases reçoit les verdicts par case de Question#blank_results" do
        skip_until_lot_a_blank_results
        raw = two_blank_numeric_question
        question = copy_question(raw)
        practice = Catalog::NotionPractice.from_raw(raw_practice(raw))

        [ [ "4,8", "3" ], [ "4,8 cm", "2" ], [ "x", "3 cm" ] ].each do |texts|
          result = check_practice_with(Notions.new(practice))
                                                   .call(actor: Student.new(role: "student"), audience: Catalog::LevelAudience.new(pairs: [ [ 1, nil ] ]),
                                                         course_slug: "c", notion_slug: "n", digest: practice.digest,
                                                         responses: { "0" => { "blanks" => { "0" => texts[0], "1" => texts[1] } } })
          expected = question.blank_results(texts).map { it ? :correct : :wrong }

          assert_equal expected, result.value.questions.first.verdicts, texts.inspect
        end
      end
    end
  end
end
