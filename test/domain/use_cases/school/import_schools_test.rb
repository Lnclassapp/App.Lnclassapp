require "test_helper"

# ADR-0030, ADR-0039: the schools adapter on the real engine and repositories, with the development referential
# (seed_referential). Schools only arrive by import, and their classrooms are born with them.
module UseCases
  module School
    class ImportSchoolsTest < ActiveSupport::TestCase
      # Classes expected per (type, cycle) with the full referential (ADR-0030).
      EXPECTED = { %w[public both] => 77, %w[private both] => 38, %w[mixed both] => 38, %w[public first] => 28,
                   %w[private first] => 12, %w[mixed first] => 12 }.freeze

      # The base refuses the classrooms of one school, every time (SC-03, atomic creation).
      class FragileClassrooms < Repositories::Classroom::ClassroomRepository
        def initialize(fragile:, **)
          super(**)
          @fragile = fragile
        end

        def insert_generated(rows:, at:)
          raise ActiveRecord::RecordNotUnique, "refus simulé" if Orm::School.exists?(id: rows.pluck(:school_id), name: @fragile)

          super
        end
      end

      # A code is taken by someone else between the validation and the write (ADR-0039 §4.5).
      class RacedClassrooms < Repositories::Classroom::ClassroomRepository
        def initialize(steal:, **)
          super(**)
          @steal = steal
        end

        def taken_join_codes
          super.tap { @steal.call }
        end
      end

      class CountingTransaction < Repositories::Shared::Transaction
        attr_reader :attempts

        def attempt(&)
          @attempts = @attempts.to_i + 1
          super
        end
      end

      setup do
        seed_referential
        @drena = create_drena(name: "Abidjan 2")
        @author = create_team_member(second_factor: false)
      end

      def adapter(classrooms: Repositories::Classroom::ClassroomRepository.new, random: SecureRandom)
        ImportSchools.new(drenas: Repositories::School::DrenaRepository.new, schools: Repositories::School::SchoolRepository.new,
                          classrooms:, taxonomy: Repositories::Catalog::TaxonomyRepository.new, random:)
      end

      def drena_entity = Repositories::School::DrenaRepository.new.find_by_slug(slug: "abidjan-2")

      # The real engine, on a report in base and its file.
      def run_import(document, adapter: self.adapter, transaction: Repositories::Shared::Transaction.new, author: @author)
        report = create_import_report(kind: "schools", imported_by: author)
        Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, io: StringIO.new(document.to_json),
                                                          filename: "ecoles.json")
        @result = UseCases::Catalog::RunImport.new(
          adapter:, reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
          schema: Repositories::Catalog::ImportSchemaValidator.new, users: Repositories::Identity::UserRepository.new,
          audit_log: Repositories::Identity::AuditLogRepository.new, transaction:, clock: Time.zone
        ).call(report_id: report.id)
        report.reload
      end

      def document(*schools, drena: "abidjan-2")
        { "format" => "lnclass.schools", "version" => 1, "drena" => drena, "schools" => schools }.compact
      end

      def validate(root, target: drena_entity)
        subject = adapter
        subject.validate_root(root:, path: "schools[0]", context: subject.prepare(target:))
      end

      def error_pairs(item) = item.errors.map { [ it.path, it.code ] }

      def classrooms_of(name) = Orm::Classroom.joins(:school).where(schools: { name: })

      test "honours the importer contract, and validate_root writes nothing" do
        subject = adapter
        assert_importer_contract ImportSchools, adapter: subject, root: { "name" => "Lycée Moderne", "type" => "public" },
                                                context: subject.prepare(target: drena_entity)
        assert_equal Policies::School::ManageSchoolPolicy, Entities::Catalog::ImportKind.fetch(ImportSchools::KIND).policy
        assert_equal ImportSchools::POLICY, Entities::Catalog::ImportKind.fetch(ImportSchools::KIND).policy
      end

      test "the aliases of the old application are read, the first present key winning" do
        item = validate({ "nom" => "  Collège  Saint Viateur ", "schoolsigle" => "CSV", "schoolstatus" => "Inactive",
                          "schooltype" => "privée" })

        assert item.valid?
        school = item.plan.fetch(:school)
        assert_equal [ "Collège Saint Viateur", "CSV", "inactive", "private", "first", @drena.id ],
                     school.values_at(:name, :sigle, :status, :school_type, :cycle, :drena_id)
        assert_equal 14, school.fetch(:public_id).length
        assert_equal [ @drena.id, "college saint viateur" ], item.key

        item = validate({ "name" => "Lycée A", "nom" => "Ignoré", "sigle" => "LA", "status" => "draft", "statut" => "active",
                          "type" => "public" })
        assert_equal [ "Lycée A", "LA", "draft", "public" ], item.plan.fetch(:school).values_at(:name, :sigle, :status, :school_type)
        assert_equal "active", validate({ "name" => "Lycée B", "statut" => "active", "type" => "public" }).plan[:school][:status]
        assert_equal "active", validate({ "name" => "Lycée C", "type" => "public" }).plan[:school][:status]
        assert_nil validate({ "name" => "Lycée D", "type" => "public", "sigle" => "  " }).plan[:school][:sigle]
      end

      test "every accepted type is stored public, private or mixed" do
        { "public" => "public", "Public" => "public", "privée" => "private", "Privée" => "private", "privé" => "private",
          "private" => "private", "mixte" => "mixed", "MIXTE" => "mixed", "mixed" => "mixed" }.each do |given, stored|
          assert_equal stored, validate({ "name" => "Lycée #{given}", "type" => given }).plan[:school][:school_type], given
        end
      end

      test "the cycle follows the word collège, accents and case ignored, unless it is given" do
        assert_equal "first", validate({ "name" => "Collège Moderne", "type" => "public" }).plan[:school][:cycle]
        assert_equal "first", validate({ "name" => "COLLÉGE Moderne", "type" => "public" }).plan[:school][:cycle]
        assert_equal "first", validate({ "name" => "college moderne", "type" => "public" }).plan[:school][:cycle]
        assert_equal "both", validate({ "name" => "Lycée Moderne", "type" => "public" }).plan[:school][:cycle]
        assert_equal "both", validate({ "name" => "Collégial Moderne", "type" => "public" }).plan[:school][:cycle]
        assert_equal "first", validate({ "name" => "Lycée Moderne", "type" => "public", "cycle" => "First" }).plan[:school][:cycle]
        assert_equal "both", validate({ "name" => "Collège X", "type" => "public", "cycle" => "both" }).plan[:school][:cycle]
      end

      test "invalid values are errors of the element, at the canonical key" do
        assert_equal [ [ "schools[0].name", "blank" ], [ "schools[0].type", "blank" ] ], error_pairs(validate({ "sigle" => "X" }))
        assert_equal [ [ "schools[0].name", "blank" ] ], error_pairs(validate({ "nom" => "  ", "schooltype" => "public" }))

        item = validate({ "name" => "L" * 151, "schoolsigle" => "S" * 21, "schooltype" => "semi-public",
                          "statut" => "fermé", "cycle" => "second" })
        assert_equal [ [ "schools[0].name", "too_long" ], [ "schools[0].sigle", "too_long" ], [ "schools[0].type", "invalid_value" ],
                       [ "schools[0].cycle", "invalid_value" ], [ "schools[0].status", "invalid_value" ] ].sort, error_pairs(item).sort
        assert_equal({ max: 150 }, item.errors.find { it.path.end_with?(".name") }.params)
        assert_equal({ value: "semi-public" }, item.errors.find { it.path.end_with?(".type") }.params)
        assert_nil item.plan
      end

      test "the DRENA of the element wins over the envelope; without either, the element is in error" do
        create_drena(name: "Bouaké 1")
        bouake = Orm::Drena.find_by!(slug: "bouake-1")

        assert_equal bouake.id, validate({ "name" => "Lycée X", "type" => "public", "drena" => "Bouaké 1" }).plan[:school][:drena_id]
        assert_equal @drena.id, validate({ "name" => "Lycée X", "type" => "public" }).plan[:school][:drena_id]

        unknown = validate({ "name" => "Lycée X", "type" => "public", "drena" => "inconnue" })
        assert_equal [ [ "schools[0].drena", "unknown_drena" ] ], error_pairs(unknown)
        assert_equal({ value: "inconnue" }, unknown.errors.first.params)

        orphan = validate({ "name" => "Lycée X", "type" => "public" }, target: nil)
        assert_equal [ [ "schools[0].drena", "unknown_drena" ] ], error_pairs(orphan)
      end

      test "the envelope DRENA is optional, but an unknown one rejects the file in bloc" do
        subject = adapter
        assert subject.resolve_target(document: {}).success?
        assert_nil subject.resolve_target(document: {}).value
        assert_equal @drena.id, subject.resolve_target(document: { "drena" => "Abidjan 2" }).value.id
        assert_equal :not_found, subject.resolve_target(document: { "drena" => "inconnue" }).code

        report = run_import(document({ "name" => "Lycée X", "type" => "public" }, drena: "inconnue"))
        assert_equal "rejected", report.status
        assert_equal [ { "path" => "drena", "code" => "unknown_target", "params" => { "value" => "inconnue" } } ], report.import_errors
        assert_equal 0, Orm::School.count
      end

      test "with the development referential: public lycée 77, private and mixed 38, public collège 28 and no second cycle" do
        report = run_import(document({ "name" => "Lycée Moderne de Cocody", "sigle" => "LMC", "type" => "public" },
                                     { "name" => "Lycée privé Les Lauriers", "type" => "privée" },
                                     { "name" => "Groupe Scolaire La Réussite", "type" => "mixte" },
                                     { "name" => "Collège Moderne de Cocody", "type" => "public" }))

        assert_equal [ "completed", 4, 4, 0, 0 ],
                     report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal({ "classrooms_created" => 181 }, report.details)
        assert_equal 77, classrooms_of("Lycée Moderne de Cocody").count
        assert_equal 38, classrooms_of("Lycée privé Les Lauriers").count
        assert_equal 38, classrooms_of("Groupe Scolaire La Réussite").count
        college = classrooms_of("Collège Moderne de Cocody")
        assert_equal 28, college.count
        assert_equal %w[first], college.joins(:level).distinct.pluck("levels.cycle")

        lycee = Orm::School.find_by!(name: "Lycée Moderne de Cocody")
        assert_equal [ "public", "both", "active", "LMC", @drena.id ], [ lycee.school_type, lycee.cycle, lycee.status, lycee.sigle, lycee.drena_id ]
        names = classrooms_of("Lycée Moderne de Cocody").pluck(:name)
        assert_includes names, "6ème 1"
        assert_includes names, "6ème 4"
        assert_includes names, "2nde A 6"
        assert_includes names, "1ère A1 6"
        assert_includes names, "Tle D 3"
        assert_includes names, "Tle D 6"
        assert_not_includes names, "Tle C 3"

        classrooms = Orm::Classroom.all
        assert_equal 181, classrooms.pluck(:join_code).uniq.size
        assert(classrooms.pluck(:join_code).all? { Entities::Classroom::JoinCode.valid?(it) })
        assert_equal [ 80 ], classrooms.distinct.pluck(:max_students)
        assert_equal [ current_school_year ], classrooms.distinct.pluck(:school_year)
        assert_equal 181, classrooms.distinct.count(:public_id)
        assert_equal 0, Orm::User.where(role: "student").count
        assert_equal 0, Orm::ClassroomStudent.count
      end

      test "a 1ère without linked series is skipped and counted in the details" do
        Orm::LevelSeries.where(level: Orm::Level.find_by!(slug: "1ere")).delete_all

        report = run_import(document({ "name" => "Lycée Moderne", "type" => "public" }, { "name" => "Collège Moderne", "type" => "public" }))

        assert_equal({ "classrooms_created" => 53 + 28, "skipped_levels" => 1 }, report.details)
        assert_equal 0, Orm::Classroom.joins(:level).where(levels: { slug: "1ere" }).count
      end

      test "a Tle series missing from the referential is skipped and counted" do
        Orm::LevelSeries.where(level: Orm::Level.find_by!(slug: "tle"), series: Orm::Series.find_by!(slug: "c")).delete_all

        report = run_import(document({ "name" => "Lycée Moderne", "type" => "public" }))

        assert_equal({ "classrooms_created" => 75, "skipped_series" => 1 }, report.details)
      end

      test "when the base refuses the classrooms of a school, that school is in error and leaves no row" do
        classrooms = FragileClassrooms.new(fragile: "Lycée Fragile")
        report = run_import(document({ "name" => "Lycée Solide", "type" => "public" }, { "name" => "Lycée Fragile", "type" => "public" },
                                     { "name" => "Collège Solide", "type" => "privée" }),
                            adapter: adapter(classrooms:))

        assert_equal [ "completed", 3, 2, 0, 1 ],
                     report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ { "path" => "schools[1]", "code" => "write_failed", "params" => {} } ], report.import_errors
        assert_not Orm::School.exists?(name: "Lycée Fragile")
        assert_equal 77 + 12, Orm::Classroom.count
        assert_equal({ "classrooms_created" => 89 }, report.details)
      end

      test "duplicates in base and in the file are skipped and counted; the existing school is not modified" do
        existing = create_school(drena: @drena, name: "Lycée Moderne d'Angré", sigle: "OLD", school_type: "private")
        before = existing.reload.attributes

        report = run_import(document({ "name" => "LYCEE moderne  d'Angre", "sigle" => "NEW", "type" => "public" },
                                     { "name" => "Lycée Blaise Pascal", "type" => "privée" },
                                     { "name" => "lycée blaise pascal", "type" => "public" }))

        assert_equal [ 3, 1, 2, 0 ], report.values_at(:total_count, :imported_count, :skipped_count, :error_count)
        assert_equal before, existing.reload.attributes
        assert_equal 0, Orm::Classroom.where(school: existing).count
        assert_equal "private", Orm::School.find_by!(name: "Lycée Blaise Pascal").school_type
      end

      test "a mixed file gives an exact report, and invalid elements leave no row nor classroom" do
        mixed = mixed(schools_document(count: 11, drena: "abidjan-2"), invalid_at: [ 6 ], duplicate_of: { 9 => 1 })
        mixed["schools"][3]["schooltype"] = "semi-public"

        report = run_import(mixed)

        assert_equal [ "completed", 11, 8, 1, 2 ],
                     report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ [ "schools[3].type", "invalid_value" ], [ "schools[6].name", "blank" ] ],
                     report.import_errors.map { it.values_at("path", "code") }
        assert_equal 8, Orm::School.count
        assert_not Orm::School.exists?(name: "Collège Moderne 4")
        expected = Orm::School.all.sum { |school| EXPECTED.fetch([ school.school_type, school.cycle ]) }
        assert_equal expected, Orm::Classroom.count
        assert_equal expected, report.details["classrooms_created"]
      end

      test "an envelope of another format is rejected, with zero writes" do
        report = run_import(schools_document(count: 3, drena: "abidjan-2").merge("format" => "lnclass.courses"))

        assert_equal "rejected", report.status
        assert_equal [ "format" ], report.import_errors.pluck("path")
        assert_equal [ 0, 0 ], [ Orm::School.count, Orm::Classroom.count ]
      end

      test "an element with a key outside the format is refused by the schema, at its path" do
        report = run_import(document({ "name" => "Lycée X", "type" => "public", "slug" => "lycee-x" },
                                     { "name" => "Lycée Y", "type" => "public" }))

        assert_equal [ 2, 1, 1 ], report.values_at(:total_count, :imported_count, :error_count)
        assert_equal [ "schema" ], report.import_errors.pluck("code")
        assert_match(/\Aschools\[0\]/, report.import_errors.first["path"])
      end

      test "a batch refused by the base (a code taken between validation and write) is replayed element by element" do
        seed = 20_260_925
        stolen = Entities::Classroom::JoinCode.generate(random: Random.new(seed))
        steal = -> { create_classroom(join_code: stolen) }
        transaction = CountingTransaction.new

        report = run_import(document({ "name" => "Lycée A", "type" => "public" }, { "name" => "Lycée B", "type" => "privée" }),
                            adapter: adapter(classrooms: RacedClassrooms.new(steal:), random: Random.new(seed)), transaction:)

        assert_equal [ "completed", 2, 0 ], report.values_at(:status, :imported_count, :error_count)
        assert_equal 1 + 2, transaction.attempts
        assert_equal 77 + 38, report.details["classrooms_created"]
        assert_equal 77 + 38 + 1, Orm::Classroom.distinct.count(:join_code)
      end

      test "an author who lost the team role is refused: the import fails, nothing is written" do
        teacher = create_teacher

        report = run_import(document({ "name" => "Lycée X", "type" => "public" }), author: teacher)

        assert_equal :forbidden, @result.code
        assert_equal "failed", report.status
        assert_not Orm::School.exists?(name: "Lycée X")
      end
    end
  end
end
