require "test_helper"

# ADR-0092 §4.1 : quatre fonctions en liste fermée, deux rangs ; le libellé du rang 2 suit le type d'établissement (ED-03).
module Entities
  module School
    class StaffPositionTest < ActiveSupport::TestCase
      test "four positions, in the order of the form" do
        assert_equal %w[head deputy educator secretary], StaffPosition::ALL
        assert StaffPosition.valid?("secretary")
        assert_not StaffPosition.valid?("principal")
        assert_not StaffPosition.valid?(nil)
      end

      test "head and deputy are management; educator, secretary, nothing or an unknown value are not" do
        assert_equal %i[management management school_life school_life], StaffPosition::ALL.map { StaffPosition.rank(it) }
        [ nil, "", "principal", "censor" ].each { assert_not StaffPosition.management?(it), it.inspect }
      end

      test "ED-03: the deputy reads as an assistant head in a public school, a director of studies elsewhere" do
        assert_equal "deputy_public", StaffPosition.label_key("deputy", school_type: "public")
        assert_equal "deputy_private", StaffPosition.label_key("deputy", school_type: "private")
        assert_equal "deputy_private", StaffPosition.label_key("deputy", school_type: "mixed")
        assert_equal "deputy_any", StaffPosition.label_key("deputy")
        assert_equal "head", StaffPosition.label_key("head", school_type: "public")
      end

      test "ED-03: every label key has its French label" do
        keys = (StaffPosition::ALL - %w[deputy]) + %w[deputy_public deputy_private deputy_any]
        keys.each { assert I18n.exists?("shared.staff_positions.#{it}", :fr), it }
        assert_equal "Adjoint au chef d'établissement", I18n.t("shared.staff_positions.deputy_public", locale: :fr)
        assert_equal "Directeur des études", I18n.t("shared.staff_positions.deputy_private", locale: :fr)
      end
    end
  end
end
