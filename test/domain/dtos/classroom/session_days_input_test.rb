require "test_helper"

module Dtos
  module Classroom
    # UDR-0062 §3.4 : les six cases « Lun. » à « Sam. » (valeurs 1 à 6). Tout décocher est permis et vaut « non renseigné ».
    class SessionDaysInputTest < ActiveSupport::TestCase
      test "lit les cases cochées, champ caché vide compris, en jours triés et dédoublonnés" do
        input = SessionDaysInput.new(classroom_public_id: "cls123", weekdays: [ "", "4", "1", "4" ])

        assert input.valid?
        assert_equal [ 1, 4 ], input.weekdays
      end

      test "aucune case cochée est valide : non renseigné" do
        [ nil, [], [ "" ] ].each do |weekdays|
          input = SessionDaysInput.new(classroom_public_id: "cls123", weekdays:)

          assert input.valid?, weekdays.inspect
          assert_equal [], input.weekdays
        end
      end

      test "refuse un jour hors de 1..6 ou illisible, et exige la classe" do
        [ [ "7" ], [ "0" ], [ "lundi" ], [ "1", "1.5" ], [ "0x1" ] ].each do |weekdays|
          input = SessionDaysInput.new(classroom_public_id: "cls123", weekdays:)

          assert_not input.valid?, weekdays.inspect
          assert input.errors.of_kind?(:weekdays, :inclusion), weekdays.inspect
        end
        input = SessionDaysInput.new(classroom_public_id: " ", weekdays: [ "1" ])

        assert_not input.valid?
        assert input.errors.of_kind?(:classroom_public_id, :blank)
      end

      # AssignmentInput porte la même étape, dans la modale « Quels jours voyez-vous la classe ? » (ADR-0072 §4.3).
      def assignment(**attributes)
        AssignmentInput.new(classroom_public_id: "cls123", assignable_type: "Exercise", assignable_key: "ex123", **attributes)
      end

      test "AssignmentInput : sans l'étape des jours, weekdays est nil et later faux, comme aujourd'hui" do
        input = assignment

        assert input.valid?
        assert_nil input.weekdays
        assert_equal false, input.later
      end

      test "AssignmentInput : « Assigner » avec des jours cochés les donne en entiers" do
        input = assignment(weekdays: [ "", "4", "1" ])

        assert input.valid?
        assert_equal [ 1, 4 ], input.weekdays
      end

      test "AssignmentInput : « Assigner » sans aucun jour coché est refusé" do
        [ [], [ "" ] ].each do |weekdays|
          input = assignment(weekdays:)

          assert_not input.valid?, weekdays.inspect
          assert input.errors.of_kind?(:weekdays, :blank), weekdays.inspect
        end
      end

      test "AssignmentInput : un jour hors de 1..6 est refusé" do
        input = assignment(weekdays: [ "1", "7" ])

        assert_not input.valid?
        assert input.errors.of_kind?(:weekdays, :inclusion)
      end

      test "AssignmentInput : « Plus tard » assigne sans jours, quoi qu'il y ait de coché" do
        [ nil, [], [ "1", "4" ], [ "9" ] ].each do |weekdays|
          input = assignment(weekdays:, later: "1")

          assert input.valid?, weekdays.inspect
          assert_equal true, input.later
          assert_nil input.weekdays, weekdays.inspect
        end
      end
    end
  end
end
