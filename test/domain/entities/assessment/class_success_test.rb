require "test_helper"

# suivi-classe-lecon, Lot B (CA-5, CA-6) : la réussite de la classe sur un exercice, meilleure copie de chaque élève.
class Entities::Assessment::ClassSuccessTest < ActiveSupport::TestCase
  def build(present_count, scores_by_student) = Entities::Assessment::ClassSuccess.build(exercise_id: "ex1", present_count:, scores_by_student:)

  test "a student counts once, on his best copy (CA-5)" do
    success = build(3, { 1 => [ 40, 70 ], 2 => [ 30 ] })

    assert_equal 3, success.present_count
    assert_equal 1, success.passed_count
    assert success.done?
  end

  test "the threshold is the pass grade, read on the displayed grade" do
    assert_equal 1, build(2, { 1 => [ Entities::Assessment::Grading::PASS_THRESHOLD ], 2 => [ 20 ] }).passed_count
  end

  test "without any copy, it is not done (CA-6)" do
    success = build(3, {})

    assert_not success.done?
    assert_equal 0, success.passed_count
  end

  test "a copy under the threshold is done but not passed" do
    success = build(2, { 1 => [ 10 ] })

    assert success.done?
    assert_equal 0, success.passed_count
  end
end
