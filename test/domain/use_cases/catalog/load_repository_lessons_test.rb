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
        def fail_running_named(kind:, prefix:, at:)
          (@failed_running ||= []) << [ kind, prefix, at ]
          @orphans || []
        end
        attr_reader :failed_running
        attr_writer :orphans
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
        attr_reader :keys
        def initialize(status: "published")
          @status = status
          @keys = { [ "thales", 1, 2, nil ] => "thales", [ "thales", 1, 2, 9 ] => "thales-serie", [ "pythagore", 1, 2, nil ] => "pythagore" }
        end
        def find_by_slug(slug:) = Course.new(5, @status)
        def slugs_by_key = @keys.dup
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

      class Referential
        include Ports::Catalog::ReferentialCompleterPort
        attr_reader :calls
        def initialize(created = {}) = (@created = created) && (@calls = 0)
        def complete = (@calls += 1) && { levels: [], series: [], pairs: [], materials: [], plan_entries: [], drenas: [], conflicts: [], interruptions: [] }.merge(@created)
      end

      setup do
        @actor = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")
        @content = JSON.generate("courses" => [ { "name" => " Thalès ", "level_name" => "3ème", "material_name" => "Maths" } ])
        @lesson = Lesson.new(import_name: "chargement-automatique-3eme-maths-thales.json", checksum_sha256: Digest::SHA256.hexdigest(@content), content: @content,
                             level_directory: "3eme", subjects: true)
        @calls = []
        @logs = []
        @logger = Object.new.tap do |logger|
          logs = @logs
          logger.define_singleton_method(:info) { |message| logs << [ :info, message ] }
          logger.define_singleton_method(:warn) { |message| logs << [ :warn, message ] }
          logger.define_singleton_method(:error) { |message| logs << [ :error, message ] }
        end
        @now = Time.zone.parse("2026-10-31 08:00")
      end

      def start_import(result = nil)
        ->(actor:, dto:) { @calls << [ :start, actor, dto.files.map(&:filename), dto.files.map { it.io.read }, dto.kind ]; result || Shared::Result.success(Struct.new(:id).new(42)) }
      end

      def run_import(status: "completed", error_count: 0, result: nil, step: :run, errors: [], imported: 1, &written)
        lambda do |report_id:|
          @calls << [ step, report_id ]
          written&.call
          result || Shared::Result.success(Struct.new(:status, :error_count, :import_errors, :imported_count).new(status, error_count, errors, imported))
        end
      end

      def cascade(result = Shared::Result.success(UseCases::Catalog::PublishCascade::Summary.new(root: nil, essentials: 0, exercises: 3, skipped: 0)))
        ->(actor:, root:, slug:) { @calls << [ :cascade, actor, root, slug ]; result }
      end

      def use_case(lessons: [ @lesson ], reports: Reports.new, users: Users.new(@actor), start: start_import, run: run_import, publish: cascade, policy: Policies::Catalog::ManageContentPolicy.new,
                   course_status: "published", drafts: Drafts.new, run_lesson: run_import(step: :run_lesson), courses: Courses.new(status: course_status),
                   referential: Referential.new, taxonomy: Taxonomy.new(Lookup.new(Level.new(1), Level.new(2))),
                   run_create: run_import(step: :run_create), manifest: :all)
        # manifest : :all (chaque fichier donné est au manifeste) ou la liste des chemins du manifeste (« niveau/matière/fichier.json »).
        manifest = lessons.map { it.import_name.delete_prefix(LoadRepositoryLessons::IMPORT_PREFIX) } if manifest == :all
        LoadRepositoryLessons.new(source: Source.new(lessons), reports:, users:, courses:, essentials: drafts, exercises: drafts,
                                  taxonomy:, start_import: start, run_import: run, manifest_paths: manifest,
                                  run_lesson_import: run_lesson, run_create_import: run_create, referential:,
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
        lesson = Lesson.new(import_name: "chargement-automatique-tle-maths-thales.json", checksum_sha256: "x", content:, level_directory: "tle", subjects: true)

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
          assert_equal [ [ :info, "[contenus] Thalès : publiée, 3 exercice(s) publié(s)" ] ], @logs
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

      test "an import that cannot start is logged with the lesson's name and the code, for an invalid upload as for one already running" do
        [ [ :invalid, { files: [ :blank ] } ], [ :conflict, { kind: [ :already_running ] } ] ].each do |code, errors|
          @logs.clear

          result = call(use_case(start: start_import(Shared::Result.failure(code, errors:)))).lessons

          assert_equal({ @lesson.import_name => :not_started }, result)
          assert_equal [ [ :error, "[contenus] Thalès : import non démarré (#{code} #{errors})" ] ], @logs
        end
      end

      test "a run that fails outright is logged and counted refused" do
        call(use_case(run: run_import(result: Shared::Result.failure(:forbidden))))

        assert_equal [ [ :error, "[contenus] Thalès : import en échec (forbidden)" ] ], @logs
      end

      test "a cascade that leaves exercises in draft warns with their number and reports the lesson partially published" do
        partial = cascade(Shared::Result.success(UseCases::Catalog::PublishCascade::Summary.new(root: nil, essentials: 0, exercises: 3, skipped: 2)))
        reports = Reports.new(loaded: { [ "course_tree", @lesson.import_name ] => @lesson.checksum_sha256 })

        assert_equal({ @lesson.import_name => :partially_published }, call(use_case(publish: partial)).lessons)
        assert_equal({ @lesson.import_name => :partially_published }, call(use_case(publish: partial, reports:, course_status: "draft")).lessons)
        assert_equal [ [ :warn, "[contenus] Thalès : 2 exercice(s) laissé(s) en brouillon (non publiables), 3 publié(s)" ] ] * 2, @logs
      end

      test "an exception on one lesson (checksum lookup, start, run) is logged with its name and class, and the next lessons are still tried" do
        second_content = JSON.generate("courses" => [ { "name" => "Pythagore", "level_name" => "3ème", "material_name" => "Maths" } ])
        second = Lesson.new(import_name: "chargement-automatique-3eme-maths-pythagore.json", checksum_sha256: "y", content: second_content, level_directory: "3eme",
                            subjects: true)
        failing = Class.new(Reports) do
          def last_loaded_checksum(kind:, file_name:) = file_name.include?("thales") ? raise("base coupée") : super
        end
        exploding_start = ->(actor:, dto:) { raise ArgumentError, "plus de place" }
        exploding_run = ->(report_id:) { raise "job tué" }

        result = call(use_case(lessons: [ @lesson, second ], reports: failing.new)).lessons

        assert_equal({ @lesson.import_name => :failed, second.import_name => :loaded }, result)
        assert_equal [ [ :error, "[contenus] Thalès : échec (RuntimeError : base coupée)" ] ], @logs.first(1)
        assert_equal :failed, call(use_case(start: exploding_start)).lessons.fetch(@lesson.import_name)
        assert_equal :failed, call(use_case(run: exploding_run)).lessons.fetch(@lesson.import_name)
        assert_includes @logs.map(&:last), "[contenus] Thalès : échec (ArgumentError : plus de place)"
        assert_includes @logs.map(&:last), "[contenus] Thalès : échec (RuntimeError : job tué)"
      end

      test "a cascade that fails leaves the lesson loaded but unpublished" do
        publish = cascade(Shared::Result.failure(:conflict))

        assert_equal({ @lesson.import_name => :unpublished }, call(use_case(publish:)).lessons)
        assert_equal [ [ :error, "[contenus] Thalès : publication refusée (conflict)" ] ], @logs
      end
      # --- ADR-0123 : Develop remplace entières les leçons v3 du programme ---

      def programme_lesson(name, folder: "tle-c", subjects: false)
        content = JSON.generate("courses" => [ { "name" => name, "level_name" => "Tle", "material_name" => "Maths" } ])
        Lesson.new(import_name: "chargement-automatique-#{folder}-maths-#{name.parameterize}.json", checksum_sha256: Digest::SHA256.hexdigest(content),
                   content:, level_directory: folder, subjects:)
      end

      test "Develop replaces whole a present programme lesson without subjects, through the whole-lesson import, then publishes it" do
        lesson = programme_lesson("Pythagore")

        assert_equal({ lesson.import_name => :replaced }, call(use_case(lessons: [ lesson ])).lessons)
        assert_equal [ [ :start, @actor, [ lesson.import_name ], [ lesson.content ], "course_tree" ], [ :run_lesson, 42 ], [ :cascade, @actor, :course, "pythagore" ] ], @calls
      end

      test "Develop creates whole an absent programme lesson and says created" do
        courses = Courses.new
        lesson = programme_lesson("Suites numériques", folder: "1ere-d")
        run_lesson = run_import(step: :run_lesson) { courses.keys[[ "suitesnumeriques", 1, 2, nil ]] = "suites-numeriques" }

        assert_equal({ lesson.import_name => :created }, call(use_case(lessons: [ lesson ], courses:, run_lesson:)).lessons)
        assert_equal [ :start, :run_lesson, :cascade ], @calls.map(&:first)
        assert_equal "suites-numeriques", @calls.last.last
      end

      test "a programme lesson with subjects keeps the exercises-only import on Develop" do
        lesson = programme_lesson("Thalès", subjects: true)

        assert_equal({ lesson.import_name => :loaded }, call(use_case(lessons: [ lesson ])).lessons)
        assert_equal %i[start run cascade], @calls.map(&:first)
      end

      test "Develop ignores a lesson outside the programme folders" do
        third = programme_lesson("Pythagore", folder: "3eme")

        assert_equal({}, call(use_case(lessons: [ third ])).lessons)
        assert_empty @calls
      end

      # --- standard-de-test §4.5 : Develop restreint au manifeste, Staging ajoute les absentes ---

      test "Develop loads only the files of the manifest: a programme file outside it is not loaded, and a present lesson outside it is neither read nor touched" do
        inside = programme_lesson("Pythagore")
        outside = programme_lesson("Thalès", folder: "tle-d")

        summary = call(use_case(lessons: [ inside, outside ], manifest: [ inside.import_name.delete_prefix("chargement-automatique-") ]))

        assert_equal({ inside.import_name => :replaced }, summary.lessons)
        assert_equal [ [ :start, @actor, [ inside.import_name ], [ inside.content ], "course_tree" ], [ :run_lesson, 42 ], [ :cascade, @actor, :course, "pythagore" ] ], @calls
        assert_includes @logs, [ :info, "[contenus] fichier(s) v3 non chargé(s) ici : tle-d 1" ]
      end

      test "Develop with an empty manifest loads no whole lesson, but a lesson with subjects keeps its exercises-only import" do
        plain = programme_lesson("Pythagore")
        subjects = programme_lesson("Thalès", subjects: true)

        assert_equal({ subjects.import_name => :loaded }, call(use_case(lessons: [ plain, subjects ], manifest: [])).lessons)
        assert_equal %i[start run cascade], @calls.map(&:first)
      end

      test "Develop never deletes: the whole-lesson import is the only writer it calls, and only for manifest files" do
        outside = programme_lesson("Thalès", folder: "tle-d")

        assert_equal({}, call(use_case(lessons: [ outside ], manifest: [])).lessons)
        assert_empty @calls
      end

      test "Staging creates an absent programme lesson through the create-only import, then publishes it" do
        courses = Courses.new
        lesson = programme_lesson("Suites numériques", folder: "1ere-d")
        run_create = run_import(step: :run_create) { courses.keys[[ "suitesnumeriques", 1, 2, nil ]] = "suites-numeriques" }

        summary = call(use_case(lessons: [ lesson ], courses:, run_create:, manifest: []), name: "Staging")

        assert_equal({ lesson.import_name => :created }, summary.lessons)
        assert_equal [ [ :start, @actor, [ lesson.import_name ], [ lesson.content ], "course_tree" ], [ :run_create, 42 ], [ :cascade, @actor, :course, "suites-numeriques" ] ], @calls
      end

      test "Staging leaves a present programme lesson intact: no upload, no import, no publication, and says ignored" do
        lesson = programme_lesson("Pythagore")

        summary = call(use_case(lessons: [ lesson ], manifest: []), name: "Staging")

        assert_equal({ lesson.import_name => :ignored }, summary.lessons)
        assert_empty @calls
      end

      test "Staging leaves a present lesson intact even when its file changed or was loaded before" do
        lesson = programme_lesson("Pythagore")
        reports = Reports.new(loaded: { [ "course_tree", lesson.import_name ] => lesson.checksum_sha256 })

        assert_equal({ lesson.import_name => :ignored }, call(use_case(lessons: [ lesson ], reports:, course_status: "draft"), name: "Staging").lessons)
        assert_empty @calls
      end

      test "Staging still refreshes only the exercises of a lesson with subjects" do
        lesson = programme_lesson("Thalès", subjects: true)

        assert_equal({ lesson.import_name => :loaded }, call(use_case(lessons: [ lesson ], manifest: []), name: "Staging").lessons)
        assert_equal %i[start run cascade], @calls.map(&:first)
      end

      test "Staging does not load a lesson outside the programme folders" do
        assert_equal({}, call(use_case(lessons: [ programme_lesson("Pythagore", folder: "3eme") ]), name: "Staging").lessons)
        assert_empty @calls
      end

      test "Staging says ignored, not created, when the create-only import skipped the lesson as a duplicate (it appeared meanwhile)" do
        lesson = programme_lesson("Suites numériques", folder: "1ere-d")
        courses = Courses.new

        summary = call(use_case(lessons: [ lesson ], courses:, run_create: run_import(step: :run_create, imported: 0), manifest: []), name: "Staging")

        assert_equal({ lesson.import_name => :ignored }, summary.lessons)
        assert_equal %i[start run_create], @calls.map(&:first)
      end

      test "the summary counts every status, so that the sum equals the number of files" do
        statuses = %i[created ignored replaced loaded unchanged republished failed refused not_started unpublished partially_published]
        lessons = statuses.each_with_index.to_h { |status, index| [ "f#{index}", status ] }.merge("g" => :ignored)
        summary = LoadRepositoryLessons::Summary.new(outcome: :done, lessons:)

        assert_equal statuses.index_with { it == :ignored ? 2 : 1 }, summary.counts
        assert_equal lessons.size, summary.counts.values.sum
        assert_equal statuses.index_with { 0 }, LoadRepositoryLessons::Summary.new(outcome: :skipped).counts
      end

      test "an unchanged programme lesson does nothing; one whose publication was interrupted is published again without reimport" do
        lesson = programme_lesson("Pythagore")
        reports = Reports.new(loaded: { [ "course_tree", lesson.import_name ] => lesson.checksum_sha256 })

        assert_equal({ lesson.import_name => :unchanged }, call(use_case(lessons: [ lesson ], reports:)).lessons)
        assert_equal({ lesson.import_name => :republished }, call(use_case(lessons: [ lesson ], reports:, course_status: "draft")).lessons)
        assert_equal [ [ :cascade, @actor, :course, "pythagore" ] ], @calls
      end

      test "a whole-lesson import that is refused is not published" do
        lesson = programme_lesson("Pythagore")

        assert_equal({ lesson.import_name => :refused }, call(use_case(lessons: [ lesson ], run_lesson: run_import(step: :run_lesson, error_count: 1))).lessons)
        assert_equal %i[start run_lesson], @calls.map(&:first)
      end
      test "a refused import says why in the log: its status and its number of errors" do
        lesson = programme_lesson("Pythagore")

        call(use_case(lessons: [ lesson ], run_lesson: run_import(step: :run_lesson, status: "completed", error_count: 2)))

        assert_equal [ [ :warn, "[contenus] Pythagore : import refusé (completed, 2 erreur(s)), voir Imports" ] ], @logs
      end

      test "a refused import logs the code, the path and the safe parameters of its first three errors, nothing else" do
        error = ->(path, code, **params) { Entities::Catalog::ImportError.new(path:, code:, params:) }
        errors = [ error.("courses[0].level_name", "unknown_level", value: "Tle"),
                   error.("courses[0]", "write_failed", exception: "ActiveRecord::InvalidForeignKey", constraint: "fk_rails_1"),
                   error.("courses[0]", "lesson_already_published", course: "Pythagore"),
                   error.("courses[0].notions[1]", "schema", keyword: "required") ]
        errors[2] = error.("courses[0].notions[0].name", "invalid_value", value: "Nom de notion")
        lesson = programme_lesson("Pythagore")

        call(use_case(lessons: [ lesson ], run_lesson: run_import(step: :run_lesson, error_count: 4, errors:)))

        assert_equal [ [ :warn, "[contenus] Pythagore : import refusé (completed, 4 erreur(s)), voir Imports : unknown_level courses[0].level_name " \
                                "(value: Tle) ; write_failed courses[0] (exception: ActiveRecord::InvalidForeignKey, constraint: fk_rails_1) ; " \
                                "invalid_value courses[0].notions[0].name" ] ], @logs
      end

      test "a whole-lesson load says replaced or created in the log before the publication" do
        lesson = programme_lesson("Pythagore")

        call(use_case(lessons: [ lesson ], publish: cascade(Shared::Result.failure(:conflict))))

        assert_equal [ [ :info, "[contenus] Pythagore : leçon remplacée entière (#{lesson.import_name})" ],
                       [ :error, "[contenus] Pythagore : publication refusée (conflict)" ] ], @logs
      end

      test "the files not loaded here are counted in one log line per level folder, so a misplaced wave shows" do
        third = programme_lesson("Pythagore", folder: "3eme")
        misplaced = programme_lesson("Suites", folder: "tle-e")

        call(use_case(lessons: [ third, misplaced, @lesson ]))

        assert_equal [ :info, "[contenus] fichier(s) v3 non chargé(s) ici : 3eme 1, tle-e 1" ], @logs.first
      end
      test "an error that cannot be read leaves the refusal logged as a refusal, without reasons" do
        broken = Object.new.tap { it.define_singleton_method(:params) { raise "illisible" } }
        lesson = programme_lesson("Pythagore")

        summary = call(use_case(lessons: [ lesson ], run_lesson: run_import(step: :run_lesson, error_count: 1, errors: [ broken ])))

        assert_equal({ lesson.import_name => :refused }, summary.lessons)
        assert_equal [ [ :warn, "[contenus] Pythagore : import refusé (completed, 1 erreur(s)), voir Imports" ] ], @logs
      end
      # --- ADR-0123 §8 (amendé le 2026-11-04) : sur Develop et Staging, le référentiel manquant est créé avant le chargement ---

      test "Develop completes the referential before loading and logs what it created" do
        referential = Referential.new(levels: [ "1ère" ], series: %w[A1 A2], pairs: [ "1ère A1", "1ère A2" ], materials: [ "EDHC" ],
                                      plan_entries: %w[a b c], drenas: [ "Abidjan 1", "Aboisso" ], conflicts: [ "matière Mathématiques" ],
                                      interruptions: [ "barème (PG::ConnectionBad : coupé)" ])

        call(use_case(referential:))

        assert_equal 1, referential.calls
        assert_equal [ [ :info, "[contenus] référentiel complété : niveaux 1ère ; séries A1, A2 ; couples 1ère A1, 1ère A2 ; matières EDHC ; " \
                                "barème 3 entrée(s) ; DRENA 2" ],
                       [ :warn, "[contenus] référentiel : non créé (déjà pris) : matière Mathématiques" ],
                       [ :error, "[contenus] référentiel interrompu : barème (PG::ConnectionBad : coupé)" ] ], @logs.first(3)
      end

      test "a complete referential logs nothing" do
        call(use_case)

        assert_empty(@logs.select { it.last.include?("référentiel") })
      end

      test "Staging, emptied, completes the referential before creating its missing lessons" do
        referential = Referential.new(levels: [ "Tle" ], series: [ "D" ], pairs: [ "Tle D" ], materials: [ "SVT" ])

        call(use_case(referential:), name: "Staging")

        assert_equal 1, referential.calls
        assert_equal [ :info, "[contenus] référentiel complété : niveaux Tle ; séries D ; couples Tle D ; matières SVT" ], @logs.first
      end

      test "production, Demo, a PR environment and an unknown name never touch the referential" do
        referential = Referential.new
        [ [ "production", false ], [ "Demo", false ], [ "Develop", true ], [ "Staging", true ], [ "Recette", false ] ].each do |name, pr|
          call(use_case(referential:), name:, pr:)
        end

        assert_equal 0, referential.calls
      end

      test "a referential that fails is logged and the lessons are still loaded" do
        failing = Referential.new.tap { it.define_singleton_method(:complete) { raise "base coupée" } }

        summary = call(use_case(referential: failing))

        assert_equal({ @lesson.import_name => :loaded }, summary.lessons)
        assert_equal [ :error, "[contenus] référentiel non complété (RuntimeError : base coupée)" ], @logs.first
      end
      test "a programme lesson whose level or material is unknown here is not taken for present, and the import says why" do
        lesson = programme_lesson("Pythagore")
        [ Lookup.new(nil, Level.new(2)), Lookup.new(Level.new(1), nil) ].each do |lookup|
          @calls.clear
          refused = run_import(step: :run_lesson, error_count: 1)

          assert_equal({ lesson.import_name => :refused }, call(use_case(lessons: [ lesson ], taxonomy: Taxonomy.new(lookup), run_lesson: refused)).lessons)
          assert_equal %i[start run_lesson], @calls.map(&:first)
        end
      end
      # --- ADR-0123 §9 : un chargement tué laisse des rapports « en cours » qui bloqueraient le suivant ---

      test "before loading, the running reports of an interrupted load are failed, and the log says how many" do
        reports = Reports.new.tap { it.orphans = %w[abc def] }

        summary = call(use_case(reports:))

        assert_equal({ @lesson.import_name => :loaded }, summary.lessons)
        assert_equal [ [ "course_tree", "chargement-automatique-", @now ] ], reports.failed_running
        assert_includes @logs, [ :warn, "[contenus] 2 import(s) d'un chargement interrompu passé(s) en échec : abc, def" ]
      end

      test "a cleanup that fails is logged and the lessons are still loaded" do
        reports = Reports.new.tap { it.define_singleton_method(:fail_running_named) { |**| raise "base coupée" } }

        assert_equal({ @lesson.import_name => :loaded }, call(use_case(reports:)).lessons)
        assert_includes @logs, [ :error, "[contenus] imports interrompus non nettoyés (RuntimeError : base coupée)" ]
      end

      test "with no orphan report the log says nothing about it, and Staging clears its orphans too" do
        reports = Reports.new

        call(use_case(reports:), name: "Staging")

        assert_equal 1, reports.failed_running.size
        assert_empty(@logs.select { it.last.include?("interrompu") })
      end
    end
  end
end
