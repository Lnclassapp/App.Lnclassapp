require "test_helper"

module UseCases
  module Catalog
    # ADR chargement-automatique-des-lecons-hors-production : le use case avec des doubles ; la vraie chaîne est dans
    # test/integration/catalog/automatic_lesson_load_test.rb.
    class LoadRepositoryLessonsTest < ActiveSupport::TestCase
      Lesson = Ports::Catalog::LessonSourcePort::LessonFile
      Level = Struct.new(:id)

      class Source
        include Ports::Catalog::LessonSourcePort
        def initialize(lessons) = @lessons = lessons
        def lessons = @lessons
      end

      class Reports
        include Ports::Catalog::ImportReportRepositoryPort
        attr_reader :rejections
        def initialize(loaded: {}) = (@loaded = loaded) && (@rejections = [])
        def last_loaded_checksum(kind:, file_name:) = @loaded[[ kind, file_name ]]
        def record_rejection(**args) = @rejections << args
      end

      class Users
        include Ports::Identity::UserRepositoryPort
        def initialize(actor) = @actor = actor
        def oldest_active_team_actor = @actor
      end

      class Courses
        include Ports::Catalog::CourseRepositoryPort
        Course = Struct.new(:id, :status)
        def initialize(status: "published") = @status = status
        def find_by_slug(slug:) = Course.new(5, @status)
        def slugs_by_key = { [ "thales", 1, 2, nil ] => "thales", [ "thales", 1, 2, 9 ] => "thales-serie" }
      end

      class Drafts
        include Ports::Assessment::ExerciseRepositoryPort
        include Ports::Catalog::EssentialRepositoryPort
        def initialize(exercises: [], essentials: []) = (@exercises = exercises) && (@essentials = essentials)
        def draft_public_ids(course_id: nil, essential_id: nil) = @exercises
        def draft_slugs(course_id:) = @essentials
      end

      Lookup = Struct.new(:level, :material) do
        def resolve_level(_) = level
        def resolve_material(_) = material
        def resolve_series(name) = (Level.new(9) if name)
      end

      Taxonomy = Struct.new(:lookup)

      setup do
        @actor = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")
        @content = JSON.generate("courses" => [ { "name" => " Thalès ", "level_name" => "3ème", "material_name" => "Maths" } ])
        @lesson = Lesson.new(import_name: "chargement-automatique-3eme-maths-thales.json", checksum_sha256: Digest::SHA256.hexdigest(@content), content: @content)
        @calls = []
        @logs = []
        @logger = Object.new.tap do |logger|
          logs = @logs
          logger.define_singleton_method(:info) { |message| logs << [ :info, message ] }
          logger.define_singleton_method(:error) { |message| logs << [ :error, message ] }
        end
        @now = Time.zone.parse("2026-10-31 08:00")
      end

      def start_import(result = nil)
        ->(actor:, dto:) { @calls << [ :start, actor, dto.files.map(&:filename), dto.files.map { it.io.read }, dto.kind ]; result || Shared::Result.success(Struct.new(:id).new(42)) }
      end

      def run_import(status: "completed", error_count: 0, result: nil)
        ->(report_id:) { @calls << [ :run, report_id ]; result || Shared::Result.success(Struct.new(:status, :error_count).new(status, error_count)) }
      end

      def cascade(result = Shared::Result.success(UseCases::Catalog::PublishCascade::Summary.new(root: nil, essentials: 0, exercises: 3, skipped: 1)))
        ->(actor:, root:, slug:) { @calls << [ :cascade, actor, root, slug ]; result }
      end

      def use_case(lessons: [ @lesson ], reports: Reports.new, users: Users.new(@actor), start: start_import, run: run_import, publish: cascade, policy: Policies::Catalog::ManageContentPolicy.new,
                   course_status: "published", drafts: Drafts.new)
        LoadRepositoryLessons.new(source: Source.new(lessons), reports:, users:, courses: Courses.new(status: course_status), essentials: drafts, exercises: drafts,
                                  taxonomy: Taxonomy.new(Lookup.new(Level.new(1), Level.new(2))), start_import: start, run_import: run,
                                  publish_cascade: publish, policy:, logger: @logger, clock: Struct.new(:now).new(@now))
      end

      def call(subject = use_case, name: "Develop", pr: false) = subject.call(environment_name: name, pr_environment: pr).value

      test "Develop loads a changed lesson: one upload under the import name, the run, then the cascade on the lesson found by its key" do
        summary = call

        assert_equal [ :done, { @lesson.import_name => :loaded } ], [ summary.outcome, summary.lessons ]
        assert_equal [ [ :start, @actor, [ @lesson.import_name ], [ @content ], "course_tree" ], [ :run, 42 ], [ :cascade, @actor, :course, "thales" ] ], @calls
      end

      test "a lesson of a series is found by its key including the series" do
        content = JSON.generate("courses" => [ { "name" => "Thalès", "level_name" => "3ème", "material_name" => "Maths", "series_name" => "D" } ])
        lesson = Lesson.new(import_name: "chargement-automatique-tle-maths-thales.json", checksum_sha256: "x", content:)

        assert_equal({ lesson.import_name => :loaded }, call(use_case(lessons: [ lesson ])).lessons)
        assert_equal "thales-serie", @calls.last.last
      end

      test "Staging loads too, with the case ignored" do
        assert_equal({ @lesson.import_name => :loaded }, call(name: "STAGING").lessons)
      end

      test "production, a PR environment and a missing name do nothing at all" do
        [ [ "production", false ], [ "Develop", true ], [ nil, false ] ].each do |name, pr|
          reports = Reports.new
          summary = call(use_case(reports:), name:, pr:)

          assert_equal [ :skipped, {} ], [ summary.outcome, summary.lessons ], name.inspect
          assert_empty reports.rejections
        end
        assert_empty @calls
      end

      test "without an active team member nothing is loaded and nothing is written, not even the unknown-environment line" do
        reports = Reports.new

        [ "Develop", "Recette" ].each do |name|
          assert_equal :no_author, call(use_case(users: Users.new(nil), reports:), name:).outcome
        end
        assert_empty @calls
        assert_empty reports.rejections
      end

      test "an unknown name loads nothing and leaves one refused line naming the environment, authored by the oldest team member" do
        reports = Reports.new

        summary = call(use_case(reports:), name: " Recette ")

        assert_equal [ :unknown_environment, {} ], [ summary.outcome, summary.lessons ]
        assert_empty @calls
        line = reports.rejections.sole
        assert_equal [ "course_tree", 7, @now, 64 ], line.values_at(:kind, :imported_by_id, :at).push(line.fetch(:checksum_sha256).size)
        assert_equal [ [ "$", "unknown_environment", { name: "Recette" } ] ], line.fetch(:errors).map { [ it.path, it.code, it.params ] }
      end

      test "a file whose checksum equals the last loaded one is left alone, with no line" do
        reports = Reports.new(loaded: { [ "course_tree", @lesson.import_name ] => @lesson.checksum_sha256 })

        summary = call(use_case(reports:))

        assert_equal({ @lesson.import_name => :unchanged }, summary.lessons)
        assert_empty @calls
      end

      test "an unchanged file whose lesson still has drafts (exercise or notion) or is not published gets its publication again, without reimport" do
        reports = Reports.new(loaded: { [ "course_tree", @lesson.import_name ] => @lesson.checksum_sha256 })
        [ { drafts: Drafts.new(exercises: [ "abc" ]) }, { drafts: Drafts.new(essentials: [ "fiche" ]) }, { course_status: "draft" } ].each do |state|
          @calls.clear
          @logs.clear

          assert_equal({ @lesson.import_name => :republished }, call(use_case(reports:, **state)).lessons, state.keys.to_s)
          assert_equal [ [ :cascade, @actor, :course, "thales" ] ], @calls
          assert_equal [ [ :info, "[contenus] Thalès : publiée, 3 exercice(s) publié(s), 1 laissé(s) en brouillon" ] ], @logs
        end
      end

      test "an unchanged file whose lesson is fully published does nothing at all" do
        reports = Reports.new(loaded: { [ "course_tree", @lesson.import_name ] => @lesson.checksum_sha256 })

        assert_equal({ @lesson.import_name => :unchanged }, call(use_case(reports:)).lessons)
        assert_empty @calls
        assert_empty @logs
      end

      test "a republication that fails, by result or by exception, is logged with the lesson's name and raises nothing" do
        reports = Reports.new(loaded: { [ "course_tree", @lesson.import_name ] => @lesson.checksum_sha256 })
        raising = ->(actor:, root:, slug:) { raise "boom" }

        assert_equal({ @lesson.import_name => :unpublished },
                     call(use_case(reports:, course_status: "draft", publish: cascade(Shared::Result.failure(:conflict)))).lessons)
        assert_equal({ @lesson.import_name => :unpublished }, call(use_case(reports:, course_status: "draft", publish: raising)).lessons)
        assert_equal [ [ :error, "[contenus] Thalès : publication refusée (conflict)" ], [ :error, "[contenus] Thalès : publication interrompue (RuntimeError : boom)" ] ], @logs
      end

      test "a file that differs from the last loaded checksum is loaded again" do
        reports = Reports.new(loaded: { [ "course_tree", @lesson.import_name ] => "autre" })

        assert_equal({ @lesson.import_name => :loaded }, call(use_case(reports:)).lessons)
      end

      test "an import that cannot start (one already running) is reported, nothing runs" do
        busy = Shared::Result.failure(:conflict, errors: { kind: [ :already_running ] })

        assert_equal({ @lesson.import_name => :not_started }, call(use_case(start: start_import(busy))).lessons)
        assert_equal [ :start ], @calls.map(&:first)
      end

      test "a lesson the import refuses (errors, rejected, forbidden) is not published" do
        [ run_import(error_count: 1), run_import(status: "rejected"), run_import(result: Shared::Result.failure(:forbidden)) ].each do |run|
          @calls.clear
          assert_equal({ @lesson.import_name => :refused }, call(use_case(run:)).lessons)
          assert_equal %i[start run], @calls.map(&:first)
        end
      end

      test "an author who may not manage contents loads nothing and leaves no line" do
        reports = Reports.new
        result = use_case(reports:, policy: ->(actor:) { Shared::Result.failure(:forbidden) }).call(environment_name: "Recette", pr_environment: false)

        assert_equal :forbidden, result.code
        assert_empty @calls
        assert_empty reports.rejections
      end

      test "a cascade that fails leaves the lesson loaded but unpublished" do
        publish = cascade(Shared::Result.failure(:conflict))

        assert_equal({ @lesson.import_name => :unpublished }, call(use_case(publish:)).lessons)
        assert_equal [ [ :error, "[contenus] Thalès : publication refusée (conflict)" ] ], @logs
      end
    end
  end
end
