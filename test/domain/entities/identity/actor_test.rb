require "test_helper"

module Entities
  module Identity
    class ActorTest < ActiveSupport::TestCase
      test "porte l'utilisateur, le rôle, le sous-rôle et l'école" do
        actor = Actor.new(user_id: 1, role: :team, team_role: "admin", school_id: nil)

        assert_equal 1, actor.user_id
        assert_equal "admin", actor.team_role
        assert actor.team?
      end

      test "sous-rôle et école sont facultatifs" do
        actor = Actor.new(user_id: 2, role: :teacher)

        assert_nil actor.team_role
        assert_nil actor.school_id
      end

      test "chaque prédicat répond à son rôle" do
        assert Actor.new(user_id: 1, role: :student).student?
        assert Actor.new(user_id: 1, role: :teacher).teacher?
        assert Actor.new(user_id: 1, role: :school_admin).school_admin?
        assert_not Actor.new(user_id: 1, role: :student).team?
      end

      test "refuse un rôle hors liste, y compris sous forme de chaîne" do
        assert_raises(ArgumentError) { Actor.new(user_id: 1, role: :parent) }
        assert_raises(ArgumentError) { Actor.new(user_id: 1, role: "student") }
      end
    end
  end
end
