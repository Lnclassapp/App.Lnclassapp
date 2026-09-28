require "test_helper"

module Entities
  module Catalog
    class ImportKindTest < ActiveSupport::TestCase
      test "quatre types fermés, sans import de DRENA" do
        assert_equal %w[schools course_tree essentials exercises], ImportKind::KINDS
        assert_not ImportKind.valid?("drenas")
        assert ImportKind.valid?(:schools)
        assert_raises(ArgumentError) { ImportKind.fetch("drenas") }
      end

      test "format, racines, cible et plafond de chaque type" do
        schools = ImportKind.fetch("schools")

        assert_equal [ "lnclass.schools", 1, "schools", "drena", false, 5_000 ],
                     [ schools.format, schools.version, schools.roots_key, schools.target_key, schools.target_required, schools.max_roots ]
        assert_nil ImportKind.fetch("course_tree").target_key
        assert_equal 500, ImportKind.fetch("course_tree").max_roots
        assert_equal [ "course", true, 2_000 ], ImportKind.fetch("essentials").then { [ it.target_key, it.target_required, it.max_roots ] }
        assert_equal [ "essential", 10_000 ], ImportKind.fetch("exercises").then { [ it.target_key, it.max_roots ] }
        assert_equal [ 20 * 1024 * 1024, 1_000, 100 ], [ ImportKind::MAX_BYTES, ImportKind::MAX_ERRORS, ImportKind::BATCH_SIZE ]
      end

      test "chaque type applique sa policy" do
        team = Identity::Actor.new(user_id: 1, role: :team)
        teacher = Identity::Actor.new(user_id: 2, role: :teacher)

        assert_equal Policies::School::ManageSchoolPolicy, ImportKind.fetch("schools").policy
        assert_equal Policies::Catalog::ManageContentPolicy, ImportKind.fetch("exercises").policy
        assert ImportKind.fetch("course_tree").authorize(actor: team).success?
        assert_equal :forbidden, ImportKind.fetch("schools").authorize(actor: teacher).code
      end

      test "the generation of the missing classrooms is a report kind, not an import kind (ADR-0056)" do
        team = Identity::Actor.new(user_id: 1, role: :team, team_role: "field")
        teacher = Identity::Actor.new(user_id: 2, role: :teacher)

        assert_equal "classrooms", ImportKind::CLASSROOM_GENERATION
        assert_not ImportKind.valid?("classrooms")
        assert_equal %w[schools course_tree essentials exercises classrooms], ImportKind::REPORT_KINDS
        assert ImportKind.authorize_report(kind: "classrooms", actor: team).success?
        assert_equal :forbidden, ImportKind.authorize_report(kind: "classrooms", actor: teacher).code
        assert_equal :forbidden, ImportKind.authorize_report(kind: :exercises, actor: teacher).code
        assert ImportKind.authorize_report(kind: "exercises", actor: team).success?
        assert_raises(KeyError) { ImportKind.authorize_report(kind: "drenas", actor: team) }
      end
    end
  end
end
