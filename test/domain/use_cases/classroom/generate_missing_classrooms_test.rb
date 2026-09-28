require "test_helper"
require_relative "../../../support/domain/taxonomy_fixture"
require_relative "../../../support/domain/fake_classroom_plan"

# ADR-0056, GC-03, GC-06, GC-07, GC-08: the generation of the missing classrooms, on simulated ports.
# ADR-0058, BC-06, BC-09: with the barème it reads once, at the start.
module UseCases
  module Classroom
    class GenerateMissingClassroomsTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 12)
      Clock = Data.define(:now)
      Candidate = Ports::School::SchoolRepositoryPort::Inserted
      Fixture = Entities::Catalog::TaxonomyFixture

      # One report in memory: claim, progress, finish, as ImportReportRepository does.
      class FakeReports
        include Ports::Catalog::ImportReportRepositoryPort

        attr_reader :report, :advances, :finished

        def initialize(status: "queued", imported_by_id: 7)
          @report = Entities::Catalog::ImportReport.new(
            id: 1, public_id: "rapport1", kind: "classrooms", status:, format_version: nil, total_count: 0, imported_count: 0,
            skipped_count: 0, error_count: 0, processed_count: 0, details: {}, import_errors: [], imported_by_id:,
            started_at: nil, finished_at: nil
          )
          @advances = []
        end

        def claim(id:, at:)
          return false unless @report.status == "queued"

          @report = @report.with(status: "validating", started_at: at)
          true
        end

        def find(id:) = @report

        def advance(id:, status:, processed_count:, format_version: nil)
          @advances << [ status, processed_count ]
          @report = @report.with(status:, processed_count:)
          true
        end

        def finish(id:, status:, counts:, details:, errors:, at:)
          @finished = { status:, counts:, details:, errors: }
          @report = @report.with(status:, **counts, details:, import_errors: errors, finished_at: at)
          true
        end
      end

      # The written classrooms decide who is still a candidate, as the NOT EXISTS of the repository.
      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        attr_reader :rows, :inserts

        def initialize(taken: Set[], refuse: [], broken: false)
          @taken = taken
          @refuse = refuse
          @broken = broken
          @rows = []
          @inserts = 0
        end

        def taken_join_codes
          raise "base indisponible" if @broken

          @taken.dup
        end

        def insert_generated(rows:, at:)
          @inserts += 1
          raise FakeTransaction::Refused if rows.any? { @refuse.include?(it[:school_id]) }

          @rows.concat(rows)
          rows.size
        end

        def school_ids(school_year) = @rows.select { it[:school_year] == school_year }.to_set { it[:school_id] }
      end

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        attr_reader :queries

        def initialize(schools, classrooms)
          @schools = schools
          @classrooms = classrooms
          @queries = []
        end

        def without_classrooms(school_year:, after_id:, limit:)
          @queries << [ school_year, after_id, limit ]
          equipped = @classrooms.school_ids(school_year)
          @schools.select { it.id > after_id && !equipped.include?(it.id) }.sort_by(&:id).first(limit)
        end
      end

      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        def initialize(lookup) = @lookup = lookup
        def lookup = @lookup
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(actor) = @actor = actor
        def actor_for(user_id:) = @actor
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :entries

        def initialize = @entries = []

        def record(action:, actor_id:, at:, subject_type: nil, subject_id: nil, metadata: {}, ip: nil)
          @entries << { action:, actor_id:, subject_type:, subject_id:, metadata: }
          true
        end
      end

      def self.school(id, name, school_type: "public", cycle: "both")
        Candidate.new(id:, public_id: "ecole#{id}", drena_id: 1, name:, school_type:, cycle:)
      end

      LYCEE = school(1, "Lycée Moderne")
      COLLEGE = school(2, "Collège Saint Paul", school_type: "private", cycle: "first")
      GROUPE = school(3, "Groupe Scolaire Espoir", school_type: "mixed")

      setup do
        @reports = FakeReports.new
        @classrooms = FakeClassrooms.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def generate(schools = [ LYCEE, COLLEGE, GROUPE ], actor: @team, lookup: Fixture.lookup, batch_size: 200,
                   reports: @reports, plan: Fixture.plan(lookup))
        @schools = FakeSchools.new(schools, @classrooms)
        @plan = FakeClassroomPlan.new(plan)
        GenerateMissingClassrooms.new(
          reports:, schools: @schools, classrooms: @classrooms, taxonomy: FakeTaxonomy.new(lookup), classroom_plan: @plan,
          users: FakeUsers.new(actor), audit_log: @audit, transaction: @transaction,
          policy: Policies::School::ManageSchoolPolicy.new, clock: Clock.new(NOW),
          random: Random.new(42), batch_size:
        ).call(report_id: 1)
      end

      def counts = @reports.finished[:counts]
      def classrooms_of(school) = @classrooms.rows.select { it[:school_id] == school.id }

      test "every candidate receives the classrooms of the import plan, for the current school year" do
        result = generate

        assert result.success?
        assert_equal "completed", result.value.status
        assert_equal({ total_count: 3, imported_count: 3, skipped_count: 0, error_count: 0 }, counts)
        assert_equal({ "classrooms_created" => 77 + 12 + 38 }, @reports.finished[:details])
        assert_equal [ 77, 12, 38 ], [ LYCEE, COLLEGE, GROUPE ].map { classrooms_of(it).size }
        assert_equal [ "2026-2027" ], @classrooms.rows.map { it[:school_year] }.uniq
        assert_includes classrooms_of(LYCEE).map { it[:name] }, "Tle D 6"
        assert(classrooms_of(COLLEGE).all? { it[:series_id].nil? && it[:level_id] <= 4 })
        assert_equal [ 14 ], @classrooms.rows.map { it[:public_id].length }.uniq
        assert_equal [ [ "importing", 0 ], [ "importing", 3 ] ], @reports.advances
        assert_equal [ { action: "import.run", actor_id: 7, subject_type: "ImportReport", subject_id: 1,
                         metadata: { kind: "classrooms", status: "completed", total_count: 3, imported_count: 3,
                                     skipped_count: 0, error_count: 0 } } ], @audit.entries
      end

      test "join codes are valid, all distinct, and never one already taken" do
        taken = Set.new(Array.new(50) { Entities::Classroom::JoinCode.generate(random: Random.new(it)) })
        @classrooms = FakeClassrooms.new(taken: taken.dup)

        generate

        codes = @classrooms.rows.map { it[:join_code] }
        assert_equal codes.size, codes.uniq.size
        assert(codes.all? { Entities::Classroom::JoinCode.valid?(it) })
        assert_empty codes.to_set & taken
      end

      test "candidates are read and written by batch, one transaction each, after the last id seen" do
        schools = Array.new(5) { self.class.school(it + 1, "Lycée #{it + 1}") }

        generate(schools, batch_size: 2)

        assert_equal [ [ "2026-2027", 0, 2 ], [ "2026-2027", 2, 2 ], [ "2026-2027", 4, 2 ], [ "2026-2027", 5, 2 ] ], @schools.queries
        assert_equal 3, @transaction.attempts
        assert_equal [ [ "importing", 0 ], [ "importing", 2 ], [ "importing", 4 ], [ "importing", 5 ] ], @reports.advances
        assert_equal 5 * 77, @classrooms.rows.size
      end

      test "a second run finds nobody left: nothing is written, the report ends at zero (idempotent)" do
        generate
        written = @classrooms.rows.size

        second = FakeReports.new
        generate(reports: second)

        assert_equal written, @classrooms.rows.size
        assert_equal({ total_count: 0, imported_count: 0, skipped_count: 0, error_count: 0 }, second.finished[:counts])
        assert_equal({ "classrooms_created" => 0 }, second.finished[:details])
      end

      test "a level without series is skipped and counted, as at import" do
        pairs = Fixture::PAIRS.except("1ere")

        generate([ LYCEE ], lookup: Fixture.lookup(pairs:))

        assert_equal 77 - 24, classrooms_of(LYCEE).size
        assert_equal({ "classrooms_created" => 53, "skipped_levels" => 1 }, @reports.finished[:details])
        assert_equal 1, counts[:imported_count]
      end

      test "with an empty referential, candidates have nothing to generate: counted, never written" do
        generate(lookup: Fixture.lookup(levels: [], pairs: {}))

        assert_equal({ total_count: 3, imported_count: 0, skipped_count: 3, error_count: 0 }, counts)
        assert_equal({ "classrooms_created" => 0 }, @reports.finished[:details])
        assert_equal 0, @classrooms.inserts
        assert_equal 0, @transaction.attempts
      end

      test "the barème is read once, at the start, and its counts are the ones generated" do
        lookup = Fixture.lookup
        sixth = lookup.level("6eme")
        entries = Fixture.plan(lookup).entries.map { it.level_id == sixth.id && it.school_type == "public" ? it.with(count: 6) : it }
        schools = Array.new(5) { self.class.school(it + 1, "Lycée #{it + 1}") }

        generate(schools, batch_size: 2, plan: Entities::Classroom::ClassroomPlan.new(entries:))

        assert_equal 1, @plan.reads
        assert_equal 5 * 79, @classrooms.rows.size
        assert_equal [ 6 ], schools.map { |school| classrooms_of(school).count { it[:level_id] == sixth.id } }.uniq
      end

      test "an undefined line of the barème gives no classroom and is counted as skipped" do
        lookup = Fixture.lookup
        entries = Fixture.plan(lookup).entries.reject { it.series_id == lookup.find_series("d").id && it.school_type == "public" }

        generate([ LYCEE ], lookup:, plan: Entities::Classroom::ClassroomPlan.new(entries:))

        assert_equal 77 - 6 - 6, classrooms_of(LYCEE).size
        assert_equal({ "classrooms_created" => 65, "skipped_series" => 2 }, @reports.finished[:details])
      end

      test "a refused batch is replayed school by school: the refused one is in error, named, the others equipped" do
        @classrooms = FakeClassrooms.new(refuse: [ COLLEGE.id ])

        result = generate

        assert result.success?
        assert_equal({ total_count: 3, imported_count: 2, skipped_count: 0, error_count: 1 }, counts)
        assert_equal [ [ "Collège Saint Paul", "write_failed" ] ], @reports.finished[:errors].map { [ it.path, it.code ] }
        assert_equal [ 77, 0, 38 ], [ LYCEE, COLLEGE, GROUPE ].map { classrooms_of(it).size }
        assert_equal({ "classrooms_created" => 115 }, @reports.finished[:details])
        assert_equal 4, @transaction.attempts
      end

      test "an author who lost the right fails the report, nothing written nor journaled" do
        teacher = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id: 1)

        result = generate(actor: teacher)

        assert_equal :forbidden, result.code
        assert_equal "failed", @reports.report.status
        assert_empty @classrooms.rows
        assert_empty @audit.entries
        assert_equal :forbidden, generate(actor: nil, reports: FakeReports.new).code
      end

      test "a report already claimed gives :conflict and writes nothing" do
        result = generate(reports: FakeReports.new(status: "importing"))

        assert_equal :conflict, result.code
        assert_equal({ base: [ :already_claimed ] }, result.errors)
        assert_empty @classrooms.rows
      end

      test "an unexpected failure marks the report failed, then is raised to the job" do
        @classrooms = FakeClassrooms.new(broken: true)

        assert_raises(RuntimeError) { generate }
        assert_equal "failed", @reports.report.status
        assert_equal({ total_count: 0, imported_count: 0, skipped_count: 0, error_count: 0 }, counts)
      end
    end
  end
end
