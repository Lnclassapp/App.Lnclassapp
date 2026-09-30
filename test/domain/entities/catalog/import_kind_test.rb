require "test_helper"

module Entities
  module Catalog
    class ImportKindTest < ActiveSupport::TestCase
      test "cinq types fermés, dont les DRENA (ADR-0066)" do
        assert_equal %w[schools course_tree essentials exercises drenas], ImportKind::KINDS
        assert ImportKind.valid?("drenas")
        assert ImportKind.valid?(:schools)
        assert_raises(ArgumentError) { ImportKind.fetch("regions") }
      end

      test "les DRENA : sans cible, 500 lignes, policy de l'organisation scolaire" do
        drenas = ImportKind.fetch("drenas")

        assert_equal [ "lnclass.drenas", 1, "drenas", nil, false, 500 ],
                     [ drenas.format, drenas.version, drenas.roots_key, drenas.target_key, drenas.target_required, drenas.max_roots ]
        assert_equal Policies::School::ManageSchoolPolicy, drenas.policy
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

      # ADR-0068 : seuls les cours complets acceptent plusieurs fichiers.
      test "plafonds de l'envoi : 50 fichiers et 50 Mo pour les cours complets, 1 fichier de 20 Mo ailleurs" do
        course_tree = ImportKind.fetch("course_tree")

        assert_equal [ 50, 50 * 1024 * 1024, true ], [ course_tree.max_files, course_tree.max_total_bytes, course_tree.multiple_files? ]
        (ImportKind::KINDS - [ "course_tree" ]).each do |kind|
          assert_equal [ 1, ImportKind::MAX_BYTES, false ], ImportKind.fetch(kind).then { [ it.max_files, it.max_total_bytes, it.multiple_files? ] }
        end
      end

      test "un type à cible n'accepte qu'un fichier" do
        schools = ImportKind.fetch("schools")

        error = assert_raises(ArgumentError) { schools.with(max_files: 2) }
        assert_match "cible", error.message
        assert_equal 2, ImportKind.fetch("course_tree").with(max_files: 2).max_files
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
        assert_equal %w[schools course_tree essentials exercises drenas classrooms], ImportKind::REPORT_KINDS
        assert ImportKind.authorize_report(kind: "classrooms", actor: team).success?
        assert_equal :forbidden, ImportKind.authorize_report(kind: "classrooms", actor: teacher).code
        assert_equal :forbidden, ImportKind.authorize_report(kind: :exercises, actor: teacher).code
        assert ImportKind.authorize_report(kind: "exercises", actor: team).success?
        assert_raises(KeyError) { ImportKind.authorize_report(kind: "regions", actor: team) }
      end
    end
  end
end
