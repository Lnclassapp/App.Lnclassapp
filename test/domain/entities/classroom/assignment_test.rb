require "test_helper"

module Entities
  module Classroom
    class AssignmentTest < ActiveSupport::TestCase
      def build(status, **attributes)
        Assignment.new(id: 1, public_id: "p", classroom_id: 2, assignable: Assignable.new(type: "Exercise", id: 1, key: "Xy12ab"),
                       status:, assigned_by_id: 3, assigned_at: Time.current, archived_at: nil, **attributes)
      end

      test "active ou archivée" do
        assert build("active").active?
        assert_not build("archived").active?
        assert_equal %w[active archived], Assignment::STATUSES
      end

      # ADR-0072 §4.3 : l'échéance est figée à l'assignation ; nulle sans jours de séance.
      test "porte son échéance, nulle par défaut" do
        assert_nil build("active").due_on
        assert_equal Date.new(2026, 10, 8), build("active", due_on: Date.new(2026, 10, 8)).due_on
        assert_includes Assignment.members, :due_on
      end

      # ADR sujets-de-devoir (ajout du 2026-10-30) : les assignations d'un même envoi partagent un batch_public_id ;
      # un exercice assigné seul n'en a pas.
      test "porte son envoi, nul pour un exercice assigné seul" do
        assert_nil build("active").batch_public_id
        assert_equal "Ab3dEf5hJk7mNp", build("active", batch_public_id: "Ab3dEf5hJk7mNp").batch_public_id
        assert_includes Assignment.members, :batch_public_id
      end
    end
  end
end
