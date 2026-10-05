require "test_helper"

module Policies
  module Catalog
    # UDR-0013, amendement du 2026-10-01 : seul l'élève est limité à son niveau ; hors niveau, 404 comme un brouillon.
    class ReadOwnLevelPolicyTest < ActiveSupport::TestCase
      Actor = Entities::Identity::Actor
      AUDIENCE = Entities::Catalog::LevelAudience.new(pairs: [ [ 7, 40 ] ])

      def check(actor, course_level) = ReadOwnLevelPolicy.new.call(actor:, audience: AUDIENCE, course_level:)

      test "un élève lit un cours de son niveau ; un autre niveau répond :not_found" do
        student = Actor.new(user_id: 1, role: :student)

        assert check(student, { level_id: 7, series_id: 40 }).success?
        assert check(student, { level_id: 7, series_id: nil }).success?
        assert_equal :not_found, check(student, { level_id: 5, series_id: nil }).code
      end

      test "enseignant, direction et équipe lisent tous les niveaux ; sans acteur, interdit" do
        [ Actor.new(user_id: 2, role: :teacher), Actor.new(user_id: 3, role: :school_admin, school_id: 9),
          Actor.new(user_id: 4, role: :team, team_role: "content") ].each do |actor|
          assert check(actor, { level_id: 5, series_id: nil }).success?, actor.role
        end
        assert_equal :forbidden, check(nil, { level_id: 7, series_id: 40 }).code
      end
    end
  end
end
