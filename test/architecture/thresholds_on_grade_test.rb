require "test_helper"

# ADR-0106: the displayed grade on 20 decides. No file of app/ compares a raw score to a pedagogical threshold: every
# rule goes through Grading.reaches?. The only exception is Grading.perfect?, the no-mistake fact behind the Diamond.
class ThresholdsOnGradeTest < ActiveSupport::TestCase
  RAW = /(?:[<>]=?)\s*(?:[\w:]+::)?[A-Z_]+_THRESHOLD\b|\b[A-Z_]+_THRESHOLD\s*[<>]=?/
  ALLOWED = [ "app/domain/entities/assessment/grading.rb:      def self.perfect?(score_percent) = score_percent >= PERFECT_THRESHOLD" ].freeze

  def raw_comparisons(source) = source.each_line.grep(RAW)

  test "no raw comparison to a threshold in app/, outside Grading.perfect?" do
    offenders = Rails.root.glob("app/**/*.{rb,erb}").flat_map do |path|
      raw_comparisons(path.read).map { "#{path.relative_path_from(Rails.root)}:#{it.chomp}" }
    end

    assert_empty offenders - ALLOWED
  end

  test "the pattern catches raw comparisons and lets reaches? through" do
    [ "score >= Grading::MASTERY_THRESHOLD", "rate < PASS_THRESHOLD", "Entities::Assessment::Grading::GOLD_THRESHOLD <= best",
      "score_percent > REMEDIATION_THRESHOLD" ].each { assert_equal 1, raw_comparisons(it).size, it }
    assert_empty raw_comparisons("Grading.reaches?(score, Grading::MASTERY_THRESHOLD)")
    assert_empty raw_comparisons("BADGE_THRESHOLDS = { bronze: PASS_THRESHOLD }")
  end
end
