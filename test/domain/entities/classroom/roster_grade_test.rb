require "test_helper"

# rapports-de-classe, Lot B (CL-15 ; décision du porteur du 2026-10-16, UDR-0108 amendée) : la liste des élèves de la page de
# classe se découpe par note sur 20 — la moyenne des meilleurs scores de l'élève aux exercices assignés à la classe.
module Entities
  module Classroom
    class RosterGradeTest < ActiveSupport::TestCase
      test "the groups, in the order of the selector: 0–10, 11–15, 16–20, then not graded yet" do
        assert_equal %w[0-10 11-15 16-20 none], RosterGrade::KEYS
      end

      test "the grade is the mean of the best scores on 20, rounded as everywhere (Grading.grade_on_20); none without a score" do
        assert_nil RosterGrade.grade_for(nil)
        assert_equal [ 0, 10, 11, 15, 16, 20 ], [ 0, 51.9, 52.5, 77.4, 77.5, 100 ].map { RosterGrade.grade_for(it) }
      end

      test "a grade falls in one group, at the bounds; no grade is « none »" do
        assert_equal %w[0-10 0-10 11-15 11-15 16-20 16-20 none], [ 0, 10, 11, 15, 16, 20, nil ].map { RosterGrade.group_for(it) }
      end

      test "the group asked for is kept when it is known, even empty; else the first non-empty one from 0–10" do
        counts = { "0-10" => 0, "11-15" => 4, "16-20" => 2, "none" => 1 }

        assert_equal "16-20", RosterGrade.selected("16-20", counts)
        assert_equal "0-10", RosterGrade.selected("0-10", counts)
        assert_equal "11-15", RosterGrade.selected("12-14", counts)
        assert_equal "11-15", RosterGrade.selected(nil, counts)
        assert_equal "none", RosterGrade.selected(nil, { "none" => 3 })
        assert_equal "0-10", RosterGrade.selected(nil, {})
      end
    end
  end
end
