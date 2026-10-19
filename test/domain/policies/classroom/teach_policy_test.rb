require "test_helper"

module Policies
  module Classroom
    class TeachPolicyTest < ActiveSupport::TestCase
      def call(actor) = TeachPolicy.new.call(actor:, classroom: Entities::Classroom::Classroom.new(teacher_ids: [ 1 ], school_id: 7))
      def actor(role, user_id = 1, school_id: 7) = Entities::Identity::Actor.new(user_id:, role:, school_id:)

      test "l'enseignant de la classe et l'équipe" do
        assert call(actor(:teacher)).success?
        assert call(actor(:team, 9)).success?
      end

      # ADR-0094 (amendement du 2026-10-16) : chaque établissement est un espace autonome.
      test "refuse son enseignant quand un autre de ses établissements est courant, en le disant" do
        result = call(actor(:teacher, 1, school_id: 8))

        assert_equal [ :forbidden, { base: [ :other_school ] } ], [ result.code, result.errors ]
      end

      test "refuse un autre enseignant, un élève, la direction et l'anonyme" do
        assert_equal :forbidden, call(actor(:teacher, 2)).code
        assert_equal :forbidden, call(actor(:student)).code
        assert_equal :forbidden, call(actor(:school_admin)).code
        assert_equal :forbidden, call(nil).code
      end
    end
  end
end
