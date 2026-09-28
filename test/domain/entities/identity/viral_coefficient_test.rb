require "test_helper"

module Entities
  module Identity
    # CP-17 (ADR-0063): k = i × c, for a cohort of teachers. A share may reach a whole group: c may exceed 1.
    class ViralCoefficientTest < ActiveSupport::TestCase
      test "k is referees per teacher of the cohort, the product of invitations per teacher and conversion" do
        viral = ViralCoefficient.new(cohort_size: 10, shares: 80, referees: 20)

        assert_in_delta 8.0, viral.invitations_per_user
        assert_in_delta 0.25, viral.conversion_rate
        assert_in_delta 2.0, viral.k
        assert_in_delta viral.invitations_per_user * viral.conversion_rate, viral.k
      end

      test "a share that brings several colleagues: a conversion above 100 %" do
        assert_in_delta 3.0, ViralCoefficient.new(cohort_size: 1, shares: 1, referees: 3).conversion_rate
      end

      test "no cohort: neither i nor k; no share: no conversion, but k still counts the referees" do
        assert_nil ViralCoefficient.new(cohort_size: 0, shares: 0, referees: 0).k
        assert_nil ViralCoefficient.new(cohort_size: 0, shares: 0, referees: 0).invitations_per_user
        viral = ViralCoefficient.new(cohort_size: 4, shares: 0, referees: 2)
        assert_nil viral.conversion_rate
        assert_in_delta 0.5, viral.k
      end

      test "the target: 0.75 is met, 0.5 is not" do
        assert ViralCoefficient.new(cohort_size: 4, shares: 12, referees: 3).on_target?
        assert_not ViralCoefficient.new(cohort_size: 4, shares: 12, referees: 2).on_target?
        assert_not ViralCoefficient.new(cohort_size: 0, shares: 0, referees: 0).on_target?
      end
    end
  end
end
