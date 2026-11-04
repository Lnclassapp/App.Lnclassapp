require "test_helper"

module Entities
  module Catalog
    # ADR standard-de-test §4.1 : le manifeste du jeu standard, lu depuis un Hash, et son contrôle contre les fichiers du dépôt.
    class StandardTestSetTest < ActiveSupport::TestCase
      def manifest
        {
          "etablissements" => [
            { "cle" => "lycee", "type" => "public", "cycle" => "both", "drena" => "Abidjan 1", "classes" => "tout_le_programme" },
            { "cle" => "college", "type" => "private", "cycle" => "first", "drena" => "Bouaké 1", "classes" => %w[6eme 5eme] },
            { "cle" => "grand", "type" => "mixed", "cycle" => "both", "drena" => "Abidjan 1", "classes" => "tout_le_programme",
              "classes_par_serie" => 2, "eleves" => 1500, "activite" => "echantillon" }
          ],
          "programme" => { "sans_serie" => %w[6eme 3eme],
                           "avec_series" => [ { "niveau" => "2nde", "series" => %w[a c] }, { "niveau" => "tle", "series" => %w[a1 d] } ] },
          "cas" => { "classe_vide" => "college/5eme", "eleve_sans_activite" => "lycee/tle-a1", "classe_pleine" => "lycee/tle-d",
                     "classe_pleine_effectif" => 40 },
          "comptes" => {
            "eleves" => "un_par_classe",
            "enseignants" => [ { "cle" => "multi-mathematiques", "matiere" => "mathematiques", "etablissements" => %w[lycee college] },
                               { "cle" => "lycee-svt", "matiere" => "svt", "etablissements" => %w[lycee] } ],
            "directions" => [ { "cle" => "direction-lycee", "etablissement" => "lycee" } ],
            "equipe" => [ { "cle" => "equipe-admin", "role" => "admin" }, { "cle" => "equipe-terrain", "role" => "field", "drena" => "Abidjan 1" } ]
          },
          "lecons" => { "tle-d/mathematiques" => "limites-et-continuite.json", "tle-a1/svt" => "reflexes.json" },
          "longue" => "3eme/mathematiques/thales.json",
          "sans_v3" => %w[6eme/francais 2nde-a/svt]
        }
      end

      def set(hash = manifest) = StandardTestSet.new(hash)

      # Les fichiers du dépôt qui satisfont exactement le manifeste ci-dessus.
      def repo_files
        { "tle-d/mathematiques/limites-et-continuite.json" => 3, "tle-a1/svt/reflexes.json" => 3,
          "3eme/mathematiques/thales.json" => 3, "6eme/francais/lecon.json" => 1, "2nde-a/svt/lecon.json" => 1 }
      end

      test "exposes the schools with their type, cycle and DRENA" do
        schools = set.schools
        assert_equal %w[lycee college grand], schools.map(&:key)
        assert_equal %w[public private mixed], schools.map(&:type)
        assert_equal %w[both first both], schools.map(&:cycle)
        assert_equal [ "Abidjan 1", "Bouaké 1", "Abidjan 1" ], schools.map(&:drena)
        assert_equal 1500, set.school("grand").students
        assert_equal "echantillon", set.school("grand").activity
        assert_nil set.school("lycee").students
      end

      test "builds one classroom per level and series from the programme" do
        keys = set.classrooms_of("lycee").map(&:key)
        assert_equal %w[6eme 3eme 2nde-a 2nde-c tle-a1 tle-d], keys
        classroom = set.classrooms_of("lycee").find { it.key == "tle-a1" }
        assert_equal [ "tle", "a1", 1 ], [ classroom.level, classroom.series, classroom.rank ]
        assert_nil set.classrooms_of("lycee").first.series
      end

      test "an explicit class list is kept as is, and several classes per series are ranked" do
        assert_equal %w[6eme 5eme], set.classrooms_of("college").map(&:key)
        grand = set.classrooms_of("grand").map(&:key)
        assert_includes grand, "tle-d-2"
        assert_includes grand, "6eme-1"
        assert_equal 2 * 6, grand.size
      end

      test "the hard cases are named" do
        cases = set.cases
        assert_equal "college/5eme", cases.empty_classroom
        assert_equal "lycee/tle-a1", cases.student_without_activity
        assert_equal "lycee/tle-d", cases.full_classroom
        assert_equal 40, cases.full_classroom_size
      end

      test "lists one student per classroom, the teachers, the heads and the team" do
        accounts = set.accounts
        assert_equal set.classrooms.size, accounts.students.size
        assert_equal [ "lycee", "6eme" ], accounts.students.first.then { [ it.school, it.classroom ] }
        assert_equal %w[multi-mathematiques lycee-svt], accounts.teachers.map(&:key)
        assert_equal %w[lycee college], accounts.teachers.first.schools
        assert_equal %w[direction-lycee], accounts.directions.map(&:key)
        assert_equal %w[admin field], accounts.team.map(&:role)
        assert_equal "Abidjan 1", accounts.team.last.drena
      end

      test "exposes the lessons, the longest one and the couples without v3" do
        lessons = set.lessons
        assert_equal %w[tle-d/mathematiques tle-a1/svt], lessons.keys
        assert_equal [ "tle-d/mathematiques/limites-et-continuite.json", "tle-a1/svt/reflexes.json" ], set.lesson_paths
        assert_equal "3eme/mathematiques/thales.json", set.longest
        assert_equal %w[6eme/francais 2nde-a/svt], set.without_v3
        assert_equal set.lesson_paths + [ set.longest ], set.expected_paths
      end

      test "a manifest that matches the repository has no error" do
        assert_empty set.errors(repo_files)
      end

      test "reports a listed file that is absent" do
        files = repo_files.except("tle-a1/svt/reflexes.json")
        assert_equal [ [ :file_missing, "tle-a1/svt/reflexes.json" ] ], set.errors(files).map { [ it.code, it.reference ] }
      end

      test "reports a listed file that is not v3" do
        files = repo_files.merge("tle-d/mathematiques/limites-et-continuite.json" => 1)
        assert_equal [ [ :not_v3, "tle-d/mathematiques/limites-et-continuite.json" ] ], set.errors(files).map { [ it.code, it.reference ] }
      end

      test "reports the longest lesson when it is absent or not v3" do
        assert_equal [ [ :file_missing, "3eme/mathematiques/thales.json" ] ],
                     set.errors(repo_files.except("3eme/mathematiques/thales.json")).map { [ it.code, it.reference ] }
        assert_equal [ [ :not_v3, "3eme/mathematiques/thales.json" ] ],
                     set.errors(repo_files.merge("3eme/mathematiques/thales.json" => 2)).map { [ it.code, it.reference ] }
      end

      test "reports a couple that has v3 files but is missing from the manifest" do
        files = repo_files.merge("tle-c/svt/autre.json" => 3, "6eme/francais/nouvelle.json" => 3)
        errors = set.errors(files)
        assert_equal [ [ :without_v3_has_v3, "6eme/francais" ], [ :couple_missing, "tle-c/svt" ] ], errors.map { [ it.code, it.reference ] }.sort_by(&:last)
      end

      test "a couple already in the manifest is not reported again for its other v3 files" do
        assert_empty set.errors(repo_files.merge("tle-d/mathematiques/autre.json" => 3))
      end

      test "a couple without v3 in the repository is not reported" do
        assert_empty set.errors(repo_files.merge("tle-c/svt/ancienne.json" => 1))
      end

      test "an error carries a readable message" do
        error = set.errors(repo_files.except("tle-a1/svt/reflexes.json")).first
        assert_includes error.message, "tle-a1/svt/reflexes.json"
      end

      test "refuses a manifest with an unknown programme keyword or a missing section" do
        assert_raises(ArgumentError) { set(manifest.merge("etablissements" => [ { "cle" => "x", "type" => "public", "cycle" => "both", "drena" => "Abidjan 1", "classes" => "autre" } ])) }
        assert_raises(KeyError) { set(manifest.except("lecons")) }
      end

      test "refuses a case that points to an unknown classroom" do
        broken = manifest.merge("cas" => manifest["cas"].merge("classe_vide" => "college/9eme"))
        assert_raises(ArgumentError) { set(broken) }
      end

      test "a manifest changed after construction does not change the set" do
        hash = manifest
        built = set(hash)
        hash["lecons"]["tle-d/mathematiques"] = "autre.json"
        hash["sans_v3"] << "5eme/svt"
        assert_equal "limites-et-continuite.json", built.lessons.fetch("tle-d/mathematiques")
        assert_equal %w[6eme/francais 2nde-a/svt], built.without_v3
        assert_predicate built.lessons, :frozen?
      end

      test "an unknown school key raises KeyError" do
        assert_raises(KeyError) { set.school("inconnu") }
      end

      test "refuses student accounts other than one per classroom" do
        broken = manifest.merge("comptes" => manifest["comptes"].merge("eleves" => "tous"))
        assert_raises(ArgumentError) { set(broken) }
      end

      test "a version that is absent, textual or not an integer is not v3" do
        path = "tle-d/mathematiques/limites-et-continuite.json"
        [ nil, "3", 3.0, 2 ].each do |version|
          assert_equal [ [ :not_v3, path ] ], set.errors(repo_files.merge(path => version)).map { [ it.code, it.reference ] }, version.inspect
        end
        assert_empty set.errors(repo_files.merge("tle-c/svt/x.json" => "3"))
      end

      test "a couple listed without v3 that has a v3 file is an error" do
        files = repo_files.merge("2nde-a/svt/lecon.json" => 3)
        assert_equal [ [ :without_v3_has_v3, "2nde-a/svt" ] ], set.errors(files).map { [ it.code, it.reference ] }
      end

      test "a couple listed without v3 that does not exist in the repository is an error" do
        files = repo_files.except("2nde-a/svt/lecon.json")
        assert_equal [ [ :couple_unknown, "2nde-a/svt" ] ], set.errors(files).map { [ it.code, it.reference ] }
      end

      test "every error code has its own message" do
        expected = { file_missing: "fichier absent du dépôt", not_v3: "fichier qui n'est pas au format 3",
                     couple_missing: "couple ayant du v3 mais absent du manifeste",
                     without_v3_has_v3: "couple listé sans v3 qui a du v3 dans le dépôt",
                     couple_unknown: "couple listé sans v3 qui n'existe pas dans le dépôt" }
        expected.each { |code, text| assert_equal "#{text} : a/b", StandardTestSet::Error.new(code, "a/b").message }
        assert_raises(ArgumentError) { StandardTestSet::Error.new(:autre, "a/b").message }
      end
    end
  end
end
