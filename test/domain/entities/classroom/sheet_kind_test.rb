require "test_helper"

module Entities
  module Classroom
    class SheetKindTest < ActiveSupport::TestCase
      test "1 ou 2 exercices : interro ; 3 ou plus : devoir" do
        assert_equal :interros, SheetKind.for(1)
        assert_equal :interros, SheetKind.for(2)
        assert_equal :devoirs, SheetKind.for(3)
        assert_equal :devoirs, SheetKind.for(10)
      end

      test "« Ma classe » lit le même seuil" do
        assert_equal SheetKind::DEVOIRS_FROM, Queries::Classroom::StudentAssignedSheetsQuery::DEVOIRS_FROM
      end
    end
  end
end
