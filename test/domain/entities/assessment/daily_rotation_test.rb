require "test_helper"

# ADR-0089 §4.1 étape 3 : la matière du jour tourne d'un cran par jour depuis le 2026-01-01 et saute celles sans candidat.
module Entities
  module Assessment
    class DailyRotationTest < ActiveSupport::TestCase
      SUBJECTS = %w[maths francais svt].freeze
      EPOCH = Date.new(2026, 1, 1)

      def subject_on(day, with_candidates: SUBJECTS, subjects: SUBJECTS)
        DailyRotation.subject_for(day:, subjects:, with_candidates:)
      end

      test "the epoch is the first of January 2026" do
        assert_equal EPOCH, DailyRotation::EPOCH
      end

      test "the subject turns one step a day and wraps around the list" do
        assert_equal %w[maths francais svt maths francais],
                     (0..4).map { subject_on(EPOCH + it) }
      end

      test "a day before the epoch still lands in the list" do
        assert_equal "svt", subject_on(EPOCH - 1)
      end

      test "a subject without candidate is skipped for the next one, around the end of the list" do
        assert_equal "svt", subject_on(EPOCH + 1, with_candidates: %w[maths svt])
        assert_equal "maths", subject_on(EPOCH + 2, with_candidates: Set.new(%w[maths francais]))
      end

      test "the next day moves to the next subject that has a candidate" do
        candidates = %w[maths francais]

        assert_equal [ "maths", "francais", "maths" ], [ EPOCH, EPOCH + 1, EPOCH + 2 ].map { subject_on(it, with_candidates: candidates) }
      end

      test "no subject has a candidate: no subject of the day" do
        assert_nil subject_on(EPOCH, with_candidates: [])
        assert_nil subject_on(EPOCH, with_candidates: %w[philosophie])
      end

      test "no subject at all: no subject of the day" do
        assert_nil subject_on(EPOCH, subjects: [], with_candidates: %w[maths])
      end
    end
  end
end
