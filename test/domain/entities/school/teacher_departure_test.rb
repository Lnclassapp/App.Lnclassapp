require "test_helper"

# ADR-0071 §4.5 : un retrait d'enseignant, ouvert jusqu'à sa réintégration.
module Entities
  module School
    class TeacherDepartureTest < ActiveSupport::TestCase
      def departure(**attributes)
        TeacherDeparture.new(id: 1, teacher_id: 2, school_id: 3, detached_by_id: 4, detached_at: Time.zone.parse("2026-10-01 09:00"),
                             reinstated_by_id: nil, reinstated_at: nil, **attributes)
      end

      test "un départ sans réintégration est ouvert" do
        assert_predicate departure, :open?
      end

      test "un départ réintégré est clos" do
        assert_not departure(reinstated_by_id: 4, reinstated_at: Time.zone.parse("2026-10-02 09:00")).open?
      end

      test "porte les colonnes de la table, rien d'autre" do
        assert_equal %i[id teacher_id school_id detached_by_id detached_at reinstated_by_id reinstated_at], TeacherDeparture.members
      end
    end
  end
end
