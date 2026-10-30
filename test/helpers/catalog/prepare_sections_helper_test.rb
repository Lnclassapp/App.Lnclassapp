require "test_helper"

# UDR-0145 §3.2 ter : les exercices d'une leçon se répartissent par type ; chaque ancre est posée une seule fois.
module Catalog
  class PrepareSectionsHelperTest < ActionView::TestCase
    Q = Queries::Catalog::PrepareInterrosQuery

    def row(id, type) = Q::ExerciseRow.new(public_id: id, title: id, exercise_type: type, status: "published", questions_count: 1, student_state: nil)

    def prepare
      Q::Prepare.new(
        groups: [ Q::Group.new(essential_slug: "a", title: "A", exercises: [ row("a1", "fixation"), row("a2", "evaluation") ]),
                  Q::Group.new(essential_slug: "b", title: "B", exercises: [ row("b1", "evaluation") ]) ],
        lesson_wide: [ row("w1", "evaluation") ], targets: nil, bare: [], material_slug: "svt")
    end

    test "filters rows by type and drops the empty groups" do
      fixation = prepare_for_type(prepare, "fixation")
      evaluation = prepare_for_type(prepare, "evaluation")

      assert_equal %w[a], fixation.groups.map(&:essential_slug)
      assert_equal %w[a1], fixation.groups.first.exercises.map(&:public_id)
      assert_empty fixation.lesson_wide
      assert_equal %w[a b], evaluation.groups.map(&:essential_slug)
      assert_equal %w[a2], evaluation.groups.first.exercises.map(&:public_id)
      assert_equal %w[w1], evaluation.lesson_wide.map(&:public_id)
    end

    test "evaluations skip the anchors the fixations already carry" do
      assert_empty prepare_anchors_taken(prepare, "fixation")
      assert_equal %w[notion-a], prepare_anchors_taken(prepare, "evaluation")
    end

    test "prepare_any? tells whether a type has a card" do
      assert prepare_any?(prepare, "evaluation")
      assert_not prepare_any?(prepare.with(groups: [], lesson_wide: []), "evaluation")
    end
  end
end
