require "test_helper"

module Entities
  module Communication
    # ADR-0078 §6 : le lecteur porte ce que l'Actor n'a pas — l'établissement et la classe principale active d'un élève.
    class ReaderTest < ActiveSupport::TestCase
      test "porte le compte, le rôle, l'établissement et la classe principale" do
        reader = Reader.new(user_id: 1, role: :student, school_id: 3, classroom_id: 11)

        assert_equal %i[user_id role school_id classroom_id], Reader.members
        assert_equal [ 1, :student, 3, 11 ], reader.deconstruct
      end

      test "un lecteur sans établissement ni classe reste un lecteur" do
        reader = Reader.new(user_id: 2, role: :student, school_id: nil, classroom_id: nil)

        assert_nil reader.school_id
        assert_nil reader.classroom_id
      end
    end
  end
end
