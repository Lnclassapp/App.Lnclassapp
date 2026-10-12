require "test_helper"

module Entities
  module School
    class SchoolTest < ActiveSupport::TestCase
      def build(**overrides)
        School.new(drena_id: 1, name: "Lycée Classique d'Abidjan", sigle: "LCA", school_type: "public", cycle: "both",
                   status: "active", **overrides)
      end

      test "un établissement complet est valide" do
        assert build.valid?
        assert build.active?
      end

      test "un établissement sans statut est actif" do
        assert_equal "active", build(status: nil).status
        assert_equal "draft", build(status: "draft").status
      end

      test "garde le nom tel que saisi, après squish" do
        school = build(name: "  lycée   MODERNE ", sigle: "  ")

        assert_equal "lycée MODERNE", school.name
        assert_nil school.sigle
        assert build(name: nil).invalid?
        assert_nil build(sigle: nil).sigle
      end

      test "borne nom et sigle, et exige une DRENA" do
        assert build(name: "a" * 151).invalid?
        assert build(sigle: "a" * 20).valid?
        assert build(sigle: "a" * 21).invalid?
        assert build(drena_id: nil).invalid?
      end

      test "type, cycle et statut sont des listes fermées" do
        assert build(school_type: "mixed", status: "draft").valid?
        assert build(school_type: "privée").invalid?
        assert build(cycle: "second").invalid?
        assert build(status: "archived").invalid?
      end

      test "un établissement mixte suit le barème du privé" do
        assert_equal "public", build.plan_type
        assert_equal "private", build(school_type: "private").plan_type
        assert_equal "private", build(school_type: "mixed").plan_type
      end

      test "un établissement du premier cycle seul le sait" do
        assert build(cycle: "first").first_cycle_only?
        assert_not build(cycle: "both").first_cycle_only?
      end
    end
  end
end
