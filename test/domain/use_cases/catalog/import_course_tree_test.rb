require "test_helper"

# CA-1 à CA-11, ADR-0116 (fiche de révision, format v3) : l'adaptateur des leçons complètes sur le vrai moteur et les vrais dépôts.
# Une leçon arrive avec toute sa descendance, en brouillon, ou pas du tout. Le schéma refuse d'abord (chemin du rapport) ; l'adaptateur
# garde ses propres règles, que les tests unitaires (validate) exercent sans le schéma.
module UseCases
  module Catalog
    class ImportCourseTreeTest < ActiveSupport::TestCase
      setup do
        @referential = seed_referential
        @author = create_team_member(team_role: "content", second_factor: false)
      end

      def adapter(writer: Repositories::Catalog::ContentTreeWriter.new, replace_exercises: false)
        ImportCourseTree.new(courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
                             taxonomy: Repositories::Catalog::TaxonomyRepository.new, writer:, replace_exercises:)
      end

      def run_import(*documents, adapter: self.adapter, author: @author)
        report = create_import_report(kind: "course_tree", imported_by: author)
        files = documents.each_with_index.map { |document, index| import_upload(io: StringIO.new(document.to_json), filename: "lecon-#{index}.json") }
        Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files:)
        UseCases::Catalog::RunImport.new(
          adapter:, reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
          schema: Repositories::Catalog::ImportSchemaValidator.new, users: Repositories::Identity::UserRepository.new,
          audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
        ).call(report_id: report.id)
        report.reload
      end

      def lesson(**overrides) = revision_sheet_document(**overrides).fetch("courses").first

      def envelope(*courses, version: 3) = { "format" => "lnclass.course-tree", "version" => version, "courses" => courses }

      def validate(root)
        subject = adapter
        subject.validate_root(root:, path: "courses[0]", context: subject.prepare(target: nil))
      end

      def pairs(item) = item.errors.map { [ it.path, it.code ] }
      def report_pairs(report) = report.import_errors.map { it.values_at("path", "code") }
      def tree_counts = [ Orm::Course, Orm::Essential, Orm::Exercise, Orm::Question, Orm::Answer ].map(&:count)
      def id_of(kind, slug) = @referential.fetch(kind).fetch(slug).id

      # Une leçon de trois notions et deux figures (CA-2) : 3 + 4 exercices.
      def lesson_of_three
        lesson(figures: [ revision_figure(key: "triangle-thales"), revision_figure(key: "carre-aire") ],
               notions: [ revision_notion("Simplifier", figure: "triangle-thales"), revision_notion("Additionner", figure: "carre-aire"),
                          revision_notion("Multiplier") ])
      end

      test "honours the importer contract, and validate_root writes nothing" do
        subject = adapter
        assert_importer_contract ImportCourseTree, adapter: subject, root: lesson, context: subject.prepare(target: nil)
        assert_equal Policies::Catalog::ManageContentPolicy, ImportCourseTree::POLICY
      end

      test "the kind is the version 3 and retires the legacy formats" do
        kind = Entities::Catalog::ImportKind.fetch("course_tree")

        assert_equal [ 3, [] ], [ kind.version, kind.legacy_versions ]
        assert_equal [ true, false, false ], [ 3, 2, 1 ].map { kind.accepts?(it) }
      end

      # CA-1
      test "a version 1 or 2 file is refused whole as retired, and no lesson is created" do
        [ 1, 2 ].each do |version|
          report = run_import(envelope(lesson, version:))

          assert_equal "rejected", report.status, version
          assert_equal [ [ "version", "format_retired" ] ], report_pairs(report), version
        end
        assert_equal [ 0, 0, 0, 0, 0 ], tree_counts
      end

      # CA-2
      test "a valid lesson is planned with its notions, sheets, figures, theme, slugs and key" do
        item = validate(lesson_of_three.merge("theme" => "burgundy"))

        assert item.valid?, item.errors.inspect
        node = item.plan
        assert_equal [ "racines-carrees", "Racines carrées", "burgundy", 2 ], [ node.slug, node.name, node.sheet_theme, node.figures.size ]
        assert_equal [ "triangle-thales", "carre-aire" ], node.figures.map { it["key"] }
        assert_equal [ [ "racines-carrees-simplifier", 1 ], [ "racines-carrees-additionner", 2 ], [ "racines-carrees-multiplier", 3 ] ],
                     node.notions.map { [ it.slug, it.position ] }
        sheet = node.notions.first.sheet
        assert_equal %w[remember method example pitfall figure_key], sheet.keys
        assert_equal [ 3, 3, "triangle-thales" ], [ sheet["method"].size, sheet["example"]["steps"].size, sheet["figure_key"] ]
        assert_nil node.notions.last.sheet["figure_key"]
        assert_equal [ "triangle-thales" ], node.notions.first.exercises.map(&:figure_key)
        assert_equal [ 14 ], node.notions.first.exercises.map { it.public_id.length }
        assert_equal [ "Problème 1", "Problème 2", "Problème 3", "Problème 4" ], node.exercises.map(&:title)
        assert_equal [ 5 ] * 3, node.notions.map { it.exercises.first.questions.size }
        assert_equal [ "racinescarrees", id_of(:levels, "3eme"), id_of(:materials, "mathematiques"), nil ], item.key
        assert_equal "blue", validate(lesson.except("theme")).plan.sheet_theme
      end

      # CA-2
      test "a lesson is written in draft with its 3 notions, 7 exercises, questions and 2 figures" do
        report = run_import(envelope(lesson_of_three))

        assert_equal [ "completed", 1, 1, 0, 0 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal({ "essentials_created" => 3, "exercises_created" => 7, "questions_created" => 35, "answers_created" => 70 }, report.details)
        assert_equal [ 1, 3, 7, 35, 70 ], tree_counts
        course = Orm::Course.find_by!(slug: "racines-carrees")
        assert_equal [ %w[triangle-thales carre-aire], "blue" ], [ course.figures.map { it["key"] }, course.sheet_theme ]
        assert_equal "geometry", course.figures.first["kind"]
        [ Orm::Course, Orm::Essential, Orm::Exercise ].each do |model|
          assert_equal [ [ "draft", @author.id, nil ] ], model.distinct.pluck(:status, :author_id, :published_at), model
        end
        notion = course.essentials.order(:position).first
        assert_equal [ "Simplifier", "triangle-thales", 3 ], [ notion.name, notion.sheet["figure_key"], notion.sheet["example"]["steps"].size ]
        assert_equal %w[triangle-thales], notion.exercises.pluck(:figure_key)
        assert_equal [ nil ] * 4, Orm::Exercise.where(course_id: course.id, essential_id: nil).pluck(:figure_key)
        assert_equal (1..7).to_a, Orm::Exercise.where(course_id: course.id).order(:position).pluck(:position)
      end

      # CA-3 (amendé le 2026-10-31) : une notion porte un ou deux exercices.
      test "a notion without exercise, or with three, is refused and the report names the notion" do
        missing = lesson
        missing["notions"][1].delete("exercise")
        three = lesson("name" => "Autre")
        exercise = three["notions"][0]["exercise"]
        three["notions"][0]["exercise"] = [ exercise, exercise, exercise ]

        report = run_import(envelope(missing, three))

        assert_equal [ 0, 2 ], report.values_at(:imported_count, :error_count)
        assert_equal [ [ "courses[0].notions[1].exercise", "essential_exercise_count" ], [ "courses[1].notions[0].exercise", "essential_exercise_count" ] ],
                     report_pairs(report)
        assert_equal [ 0, 0, 0, 0, 0 ], tree_counts
        item = validate(missing)
        assert_equal({ course: "Racines carrées", name: "Calculer avec des racines", count: 0 }, item.errors.first.params)
        assert_equal 3, validate(three).errors.first.params[:count]
        assert_equal [ [ "courses[0].notions[0].exercise", "essential_exercise_count" ] ], pairs(validate(lesson.tap { it["notions"][0]["exercise"] = [] }))
      end

      test "a notion with two exercises (list) or one (list or object) is imported, both attached to the notion in order" do
        two = lesson
        first = two["notions"][0]["exercise"]
        second = Marshal.load(Marshal.dump(first)).merge("title" => "Second exercice de la notion")
        two["notions"][0]["exercise"] = [ first, second ]
        two["notions"][1]["exercise"] = [ two["notions"][1]["exercise"] ]

        report = run_import(envelope(two))

        assert_equal [ 1, 0 ], report.values_at(:imported_count, :error_count), report.import_errors.inspect
        course = Orm::Course.find_by!(slug: "racines-carrees")
        notion = course.essentials.order(:position).first
        assert_equal [ first["title"], "Second exercice de la notion" ], notion.exercises.order(:position).pluck(:title)
        assert_equal 1, course.essentials.order(:position).second.exercises.count
        assert_equal 4, Orm::Exercise.where(course_id: course.id, essential_id: nil).count
      end

      test "an invalid exercise inside the list is reported at its own index" do
        bad = lesson
        exercise = bad["notions"][0]["exercise"]
        bad["notions"][0]["exercise"] = [ exercise, exercise.merge("questions" => exercise["questions"].first(2)) ]

        assert_includes pairs(validate(bad)), [ "courses[0].notions[0].exercise[1].questions", "too_few_questions" ]
      end

      # CA-4
      test "a lesson with 3 or 5 problems is refused" do
        [ 3, 5 ].each do |count|
          report = run_import(envelope(lesson("exercises" => Array.new(count) { revision_exercise("Problème #{it}") })))

          assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count), count
          assert_equal [ [ "courses[0].exercises", "lesson_exercise_count" ] ], report_pairs(report), count
        end
        item = validate(lesson("exercises" => Array.new(3) { revision_exercise("Problème #{it}") }))
        assert_equal [ [ "courses[0].exercises", "lesson_exercise_count" ] ], pairs(item)
        assert_equal({ course: "Racines carrées", count: 3, expected: 4 }, item.errors.first.params)
      end

      # CA-5
      test "an exercise of fewer than 5 or more than 30 questions is refused, the report names the exercise" do
        short = lesson
        short["notions"][1]["exercise"]["questions"].pop
        problem = lesson("name" => "Autre")
        problem["exercises"][2]["questions"].pop

        report = run_import(envelope(short, problem))

        assert_equal [ [ "courses[0].notions[1].exercise.questions", "too_few_questions" ], [ "courses[1].exercises[2].questions", "too_few_questions" ] ],
                     report_pairs(report)
        item = validate(short)
        assert_equal [ [ "courses[0].notions[1].exercise.questions", "too_few_questions" ] ], pairs(item)
        assert_equal({ title: "Exercice sur Calculer avec des racines", count: 4, min: 5 }, item.errors.first.params)
        assert_equal [ [ "courses[0].exercises[2].questions", "too_few_questions" ] ], pairs(validate(problem))
        none = lesson
        none["exercises"][0]["questions"] = []
        assert_equal [ [ "courses[0].exercises[0].questions", "too_few_questions" ] ], pairs(validate(none))
        many = lesson
        many["exercises"][0]["questions"] = Array.new(31) { revision_question(it + 1) }
        assert_equal [ [ "courses[0].exercises[0].questions", "invalid_count" ] ], report_pairs(run_import(envelope(many)))
      end

      # CA-6
      test "a question without written correction is refused, the report names the question" do
        empty = lesson
        empty["notions"][0]["exercise"]["questions"][3]["explanation"] = ""
        missing = lesson("name" => "B")
        missing["exercises"][1]["questions"][4].delete("explanation")
        short = lesson("name" => "C")
        short["exercises"][0]["questions"][0]["explanation"] = "Trop court."
        long = lesson("name" => "D")
        long["exercises"][0]["questions"][0]["explanation"] = "a" * 2_001

        assert_equal [ [ "courses[0].notions[0].exercise.questions[3].explanation", "blank" ] ], report_pairs(run_import(envelope(empty)))
        assert_equal [ [ "courses[0].exercises[1].questions[4].explanation", "blank" ] ], report_pairs(run_import(envelope(missing)))
        assert_equal [ [ "courses[0].exercises[0].questions[0].explanation", "too_short" ] ], report_pairs(run_import(envelope(short)))
        assert_equal [ [ "courses[0].exercises[0].questions[0].explanation", "too_long" ] ], report_pairs(run_import(envelope(long)))

        blank = lesson
        blank["notions"][0]["exercise"]["questions"][1]["explanation"] = "   "
        assert_equal [ [ "courses[0].notions[0].exercise.questions[1].explanation", "blank" ] ], pairs(validate(blank))
        assert_equal [ [ "courses[0].exercises[0].questions[0].explanation", "too_short" ] ], pairs(validate(short))
        assert_equal [ [ "courses[0].exercises[0].questions[0].explanation", "too_long" ] ], pairs(validate(long))
      end

      # CA-7
      test "a method of 4 steps and an example of 3 is refused, the report names the notion" do
        broken = lesson
        broken["notions"][1]["method"] << "Vérifier le résultat."

        report = run_import(envelope(broken))

        assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count)
        assert_equal [ [ "courses[0].notions[1].example.steps", "example_steps_mismatch" ] ], report_pairs(report)
        assert_equal 0, Orm::Course.count
      end

      test "the sheet rules of a notion: blank text, too few steps, and a notion name used twice" do
        blank = lesson
        blank["notions"][0]["pitfall"] = "  "
        assert_equal [ [ "courses[0].notions[0].pitfall", "blank" ] ], pairs(validate(blank))
        steps = lesson
        steps["notions"][0]["method"] = [ "Seule étape." ]
        assert_equal [ [ "courses[0].notions[0].method", "invalid_count" ], [ "courses[0].notions[0].example.steps", "example_steps_mismatch" ] ],
                     pairs(validate(steps))
        twice = lesson
        twice["notions"][1]["name"] = " SIMPLIFIER une racine carrée "
        assert_equal [ [ "courses[0].notions[1].name", "invalid_value" ] ], pairs(validate(twice))
      end

      test "a figure the browser would refuse (missing required parameter, inverted bounds) is refused at the figure path" do
        missing = lesson("name" => "Sans bornes")
        missing["figures"][0].merge!("kind" => "coordinate_plane", "params" => { "xmin" => -5, "xmax" => 5, "ymin" => -5 })
        inverted = lesson("name" => "Inversée")
        inverted["figures"][0].merge!("kind" => "number_line", "params" => { "min" => 5, "max" => 1, "step" => 1 })

        item = validate(missing)
        assert_equal [ [ "courses[0].figures[0].params.ymax", "figure_invalid" ] ], pairs(item)
        assert_equal({ param: "ymax" }, item.errors.first.params)
        assert_equal [ [ "courses[0].figures[0].params.max", "figure_invalid" ] ], pairs(validate(inverted))
        assert_equal 2, run_import(envelope(missing, inverted)).error_count
      end

      # CA-8
      test "a figure of unknown kind, a parameter out of bounds or without description is refused, naming the figure and the parameter" do
        unknown = lesson
        unknown["figures"][0]["kind"] = "hologram"
        far = lesson("name" => "Loin")
        far["figures"][0]["params"]["points"][0]["x"] = 99
        bare = lesson("name" => "Nue")
        bare["figures"][0]["description"] = "Courte."

        report = run_import(envelope(unknown, far, bare))

        assert_equal [ 0, 3 ], report.values_at(:imported_count, :error_count)
        paths = report.import_errors.map { it["path"] }
        assert_equal [ true ] * 3, [ "courses[0].figures[0]", "courses[1].figures[0]", "courses[2].figures[0].description" ].map { |path| paths.any? { it.start_with?(path) } }

        item = validate(far)
        assert_equal [ [ "courses[0].figures[0].params.points[0].x", "figure_invalid" ] ], pairs(item)
        assert_equal({ param: "points[0].x" }, item.errors.first.params)
        assert_equal [ [ "courses[0].figures[0].kind", "figure_invalid" ] ], pairs(validate(unknown))
        assert_equal [ [ "courses[0].figures[0].description", "figure_invalid" ] ], pairs(validate(bare))
      end

      test "two figures with the same key are refused at the second one" do
        item = validate(lesson("figures" => [ revision_figure, revision_figure ]))

        assert_equal [ [ "courses[0].figures[1].key", "figure_invalid" ] ], pairs(item)
        assert_equal({ param: "key" }, item.errors.first.params)
      end

      # CA-9
      test "a notion or an exercise citing a figure absent from the lesson is refused" do
        notion = lesson
        notion["notions"][0]["figure"] = "absente"
        exercise = lesson
        exercise["exercises"][0]["figure"] = "absente"
        sub = lesson
        sub["notions"][1]["exercise"]["figure"] = "absente"

        assert_equal [ [ "courses[0].notions[0].figure", "figure_missing" ] ], pairs(validate(notion))
        assert_equal({ key: "absente" }, validate(notion).errors.first.params)
        assert_equal [ [ "courses[0].exercises[0].figure", "figure_missing" ] ], pairs(validate(exercise))
        assert_equal [ [ "courses[0].notions[1].exercise.figure", "figure_missing" ] ], pairs(validate(sub))
        report = run_import(envelope(sub))
        assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count)
        assert_equal [ [ "courses[0].notions[1].exercise.figure", "figure_missing" ] ], report_pairs(report)
        assert_equal 0, Orm::Course.count
      end

      test "the referential is resolved, never created" do
        item = validate(lesson(level_name: "Terminale", material_name: "Astronomie", series_name: "Z"))

        assert_equal [ [ "courses[0].level_name", "unknown_level" ], [ "courses[0].material_name", "unknown_material" ],
                       [ "courses[0].series_name", "unknown_series" ] ], pairs(item)
        assert_equal [ 7, 5, 6 ], [ Orm::Level.count, Orm::Series.count, Orm::Material.count ]
      end

      test "a lesson of a level with a linked series is planned with the series and keyed on it" do
        item = validate(lesson(level_name: "Tle", series_name: "D"))

        assert item.valid?, item.errors.inspect
        assert_equal id_of(:series, "d"), item.plan.series_id
        assert_equal [ "racinescarrees", id_of(:levels, "tle"), id_of(:materials, "mathematiques"), id_of(:series, "d") ], item.key
      end

      test "a root that is not an object is a schema error, without raising" do
        [ "lecon", nil, [] ].each { |root| assert_equal [ [ "courses[0]", "schema" ] ], pairs(validate(root)), root.inspect }
      end

      test "a figure, a notion or a problem that is not an object is refused at its path, without raising" do
        figures = validate(lesson("figures" => [ "x", revision_figure ]))
        notions = validate(lesson("notions" => [ "x", revision_notion("Simplifier") ]))
        problems = validate(lesson("exercises" => [ 5, *Array.new(3) { revision_exercise("Problème") } ]))

        assert_includes pairs(figures), [ "courses[0].figures[0]", "figure_invalid" ]
        assert_includes pairs(notions), [ "courses[0].notions[0]", "schema" ]
        assert_equal [ [ "courses[0].exercises[0]", "schema" ] ], pairs(problems)
      end

      test "an exercise without statement is refused at its statement" do
        broken = lesson
        broken["exercises"][1]["statement"] = "  "

        assert_equal [ [ "courses[0].exercises[1].statement", "blank" ] ], pairs(validate(broken))
      end

      test "a question of any type keeps the structure rules of the other imports" do
        broken = lesson
        broken["exercises"][0]["questions"][0]["answers"].each { it["correct"] = true }

        assert_equal [ [ "courses[0].exercises[0].questions[0].answers", "question_structure" ] ], pairs(validate(broken))
      end

      test "the same lesson twice in one file is imported once and counted skipped" do
        report = run_import(envelope(lesson, lesson))

        assert_equal [ 2, 1, 1, 0 ], report.values_at(:total_count, :imported_count, :skipped_count, :error_count)
        assert_equal 1, Orm::Course.count
      end

      # CA-10
      test "a published or archived lesson is refused with its name and nothing of it changes" do
        run_import(envelope(lesson))
        course = Orm::Course.find_by!(slug: "racines-carrees")
        %w[published archived].each do |status|
          course.update_columns(status:, published_at: Time.current, archived_at: (Time.current if status == "archived"))
          before = [ tree_counts, course.essentials.pluck(:id).sort, Orm::Exercise.where(course_id: course.id).pluck(:id).sort ]

          report = run_import(envelope(lesson("subtitle" => "Nouveau")))

          assert_equal [ "completed", 0, 1 ], report.values_at(:status, :imported_count, :error_count), status
          assert_equal [ [ "courses[0]", "lesson_already_published" ] ], report_pairs(report), status
          assert_equal({ "course" => "Racines carrées" }, report.import_errors.first["params"], status)
          assert_equal before, [ tree_counts, course.essentials.pluck(:id).sort, Orm::Exercise.where(course_id: course.id).pluck(:id).sort ], status
          assert_equal "Calculer et simplifier", course.reload.subtitle, status
        end
      end

      test "a draft lesson whose exercise was published is not replaced" do
        run_import(envelope(lesson))
        Orm::Exercise.where(course_id: Orm::Course.find_by!(slug: "racines-carrees").id).first.update_columns(status: "published", published_at: Time.current)

        report = run_import(envelope(lesson))

        assert_equal [ [ "courses[0]", "lesson_already_published" ] ], report_pairs(report)
      end

      test "a draft lesson published between the validation and the writing is reported as already published, not as a write failure" do
        run_import(envelope(lesson))
        course = Orm::Course.find_by!(slug: "racines-carrees")
        racing = Class.new(SimpleDelegator) do
          define_method(:replace_draft) do |**args|
            Orm::Course.where(id: args.fetch(:course_id)).update_all(status: "published", published_at: Time.current)
            super(**args)
          end
        end.new(Repositories::Catalog::ContentTreeWriter.new)
        before = tree_counts

        report = run_import(envelope(lesson("subtitle" => "Nouveau")), adapter: adapter(writer: racing))

        assert_equal [ "completed", 0, 1 ], report.values_at(:status, :imported_count, :error_count)
        assert_equal [ [ "courses[0]", "lesson_already_published" ] ], report_pairs(report)
        assert_equal({ "course" => "Racines carrées" }, report.import_errors.first["params"])
        assert_equal [ before, "Calculer et simplifier" ], [ tree_counts, course.reload.subtitle ]
      end

      # --- Chargement automatique hors production : seuls les exercices, problèmes et sujets d'une leçon présente sont remplacés ---

      def publish_lesson
        course = Orm::Course.find_by!(slug: "racines-carrees")
        course.update_columns(status: "published", published_at: Time.current)
        Orm::Essential.where(course_id: course.id).update_all(status: "published", published_at: Time.current)
        Orm::Exercise.where(course_id: course.id).update_all(status: "published", published_at: Time.current)
        course
      end

      test "by hand, a published lesson stays refused whatever the file holds (the replace mode is opt-in)" do
        run_import(envelope(lesson))
        course = publish_lesson
        before = Orm::Exercise.where(course_id: course.id).pluck(:id).sort

        report = run_import(envelope(lesson("subtitle" => "Nouveau")))

        assert_equal [ [ "courses[0]", "lesson_already_published" ] ], report_pairs(report)
        assert_equal before, Orm::Exercise.where(course_id: course.id).pluck(:id).sort
      end

      test "in replace mode a published lesson keeps its course and sheets, and gets the exercises of the file in draft" do
        run_import(envelope(lesson))
        course = publish_lesson
        notion_ids = course.essentials.order(:position).pluck(:id)
        file = lesson("subtitle" => "Changé", "name" => "Racines carrées", "theme" => "teal").tap { it["exercises"].each { |e| e["title"] = "Nouveau #{e['title']}" } }

        report = run_import(envelope(file), adapter: adapter(replace_exercises: true))

        assert_equal [ "completed", 1, 0 ], report.values_at(:status, :imported_count, :error_count)
        assert_equal [ "published", "Calculer et simplifier", "blue" ], course.reload.values_at(:status, :subtitle, :sheet_theme)
        assert_equal notion_ids, course.essentials.order(:position).pluck(:id)
        assert_equal [ "published" ], course.essentials.distinct.pluck(:status)
        assert_equal [ "draft" ], Orm::Exercise.where(course_id: course.id).distinct.pluck(:status)
        assert_equal 6, Orm::Exercise.where(course_id: course.id).count
        assert_equal 4, Orm::Exercise.where(course_id: course.id, essential_id: nil).where("title LIKE 'Nouveau %'").count
        assert_equal 0, report.details.fetch("essentials_created")
      end

      test "in replace mode a draft lesson is treated the same way, and an absent lesson is created whole" do
        run_import(envelope(lesson))
        course = Orm::Course.find_by!(slug: "racines-carrees")
        notion_ids = course.essentials.order(:position).pluck(:id)
        other = lesson("name" => "Autre leçon")

        report = run_import(envelope(lesson, other), adapter: adapter(replace_exercises: true))

        assert_equal [ "completed", 2, 0 ], report.values_at(:status, :imported_count, :error_count)
        assert_equal notion_ids, course.reload.essentials.order(:position).pluck(:id)
        assert_equal 2, Orm::Course.count
        assert_equal [ "draft" ], Orm::Course.where(name: "Autre leçon").first.essentials.distinct.pluck(:status)
      end

      test "in replace mode a notion of the file missing from the lesson refuses it with the notion's name, and nothing is replaced" do
        run_import(envelope(lesson))
        course = publish_lesson
        before = Orm::Exercise.where(course_id: course.id).pluck(:id).sort
        file = lesson(notions: [ revision_notion("Simplifier une racine carrée", figure: "triangle-thales"), revision_notion("  Une   notion nouvelle ") ])

        report = run_import(envelope(file), adapter: adapter(replace_exercises: true))

        assert_equal [ "completed", 0, 1 ], report.values_at(:status, :imported_count, :error_count)
        assert_equal [ [ "courses[0].notions[1].name", "notion_not_found" ] ], report_pairs(report)
        assert_equal({ "name" => "Une notion nouvelle" }, report.import_errors.first["params"])
        assert_equal before, Orm::Exercise.where(course_id: course.id).pluck(:id).sort
      end

      # --- ADR-0121 §4, CA-9 : l'indice d'un exercice et les sujets de devoir ---

      def subject_of(title, exercises: 4, notions: "Thalès · proportionnalité", **extra)
        { "title" => title, "notions" => notions, "exercises" => Array.new(exercises) { revision_exercise("#{title} · exercice #{it + 1}") } }.merge(extra)
      end

      def lesson_with_subjects(count = 3, **extra)
        hinted = revision_notion("Simplifier").tap { it["exercise"]["hint"] = "  Pense à factoriser par un carré parfait.  " }
        lesson(notions: [ hinted, revision_notion("Additionner") ], subjects: Array.new(count) { subject_of("Sujet #{it + 1} · Thalès") }, **extra)
      end

      def write_item(item, adapter: self.adapter)
        adapter.write(items: [ item ], author_id: @author.id, at: Time.zone.parse("2026-10-30 10:00"))
      end

      test "a lesson with hints and 3 subjects is planned: hints stripped, subjects numbered from 1, exercises in order" do
        item = validate(lesson_with_subjects)

        assert item.valid?, item.errors.inspect
        node = item.plan
        assert_equal [ "Pense à factoriser par un carré parfait.", nil ], node.notions.map { it.exercises.first.hint }
        assert_equal [ [ 1, "Sujet 1 · Thalès", "Thalès · proportionnalité", nil ], [ 2, "Sujet 2 · Thalès", "Thalès · proportionnalité", nil ],
                       [ 3, "Sujet 3 · Thalès", "Thalès · proportionnalité", nil ] ],
                     node.subjects.map { [ it.position, it.title, it.notions, it.course_id ] }
        assert_equal [ 4, 4, 4 ], node.subjects.map { it.exercises.size }
        assert_equal [ "Sujet 1 · Thalès · exercice 1", "Sujet 1 · Thalès · exercice 2" ], node.subjects.first.exercises.first(2).map(&:title)
        assert_equal [ [ nil ] * 4 ], [ node.exercises.map(&:hint) ]
        assert_empty validate(lesson).plan.subjects
      end

      test "a lesson with hints and 3 subjects is written: hints, subjects, their 12 exercises without notion, in order" do
        written = write_item(validate(lesson_with_subjects))

        assert_equal 1, written[:imported]
        course = Orm::Course.find_by!(slug: "racines-carrees")
        assert_equal [ [ 1, "Sujet 1 · Thalès", "Thalès · proportionnalité" ], [ 2, "Sujet 2 · Thalès", "Thalès · proportionnalité" ],
                       [ 3, "Sujet 3 · Thalès", "Thalès · proportionnalité" ] ],
                     Orm::Subject.where(course_id: course.id).order(:position).pluck(:position, :title, :notions)
        assert_equal [ "Pense à factoriser par un carré parfait." ], Orm::Exercise.where(course_id: course.id).where.not(hint: nil).pluck(:hint)
        subject = Orm::Subject.find_by!(course_id: course.id, position: 2)
        assert_equal [ [ "Sujet 2 · Thalès · exercice 1", nil ], [ "Sujet 2 · Thalès · exercice 2", nil ], [ "Sujet 2 · Thalès · exercice 3", nil ],
                       [ "Sujet 2 · Thalès · exercice 4", nil ] ],
                     subject.exercises.pluck(:title, :essential_id)
        assert_equal 2 + 4 + 12, Orm::Exercise.where(course_id: course.id).count
        assert_equal (1..18).to_a, Orm::Exercise.where(course_id: course.id).order(:position).pluck(:position)
        assert_equal [ "draft" ], Orm::Exercise.distinct.pluck(:status)
      end

      test "a draft lesson reimported with other subjects replaces them, and the subject rows follow" do
        write_item(validate(lesson_with_subjects))
        course = Orm::Course.find_by!(slug: "racines-carrees")

        item = validate(lesson_with_subjects(1, "subtitle" => "Nouveau"))
        assert item.valid?, item.errors.inspect
        assert_equal [ :replace ], item.key.first(1)
        assert_equal [ course.id ], item.plan.subjects.map(&:course_id)
        write_item(item)

        assert_equal [ [ "Sujet 1 · Thalès" ] ], [ Orm::Subject.where(course_id: course.id).pluck(:title) ]
        assert_equal 2 + 4 + 4, Orm::Exercise.where(course_id: course.id).count
      end

      # CA-9
      test "a subject whose exercise has a notion is refused, and the error names the subject" do
        bad = subject_of("Sujet 2 · Pythagore").tap { it["exercises"][1]["notion"] = "Simplifier une racine carrée" }
        item = validate(lesson(subjects: [ subject_of("Sujet 1 · Thalès"), bad ]))

        assert_not item.valid?
        assert_equal [ [ "courses[0].subjects[1].exercises[1].notion", ImportCourseTree::NOTION_IN_SUBJECT ] ], pairs(item)
        assert_equal({ subject: "Sujet 2 · Pythagore" }, item.errors.first.params)
        assert_nil item.plan
        blank = subject_of("Sujet 1").tap { it["exercises"][0]["notion"] = "  " }
        assert validate(lesson(subjects: [ blank ])).valid?
        assert_equal 0, tree_counts.sum
      end

      test "hint, title and notions outside their bounds are refused with a named error, nothing is written" do
        long = ->(size) { "é" * size }
        cases = {
          [ "courses[0].subjects[0].exercises[0].hint", "blank" ] => subject_of("S").tap { it["exercises"][0]["hint"] = "  " },
          [ "courses[0].subjects[0].exercises[0].hint", "too_long" ] => subject_of("S").tap { it["exercises"][0]["hint"] = long.(401) },
          [ "courses[0].subjects[0].title", "blank" ] => subject_of(" "),
          [ "courses[0].subjects[0].title", "too_long" ] => subject_of("S").merge("title" => long.(201)),
          [ "courses[0].subjects[0].notions", "blank" ] => subject_of("S", notions: " "),
          [ "courses[0].subjects[0].notions", "too_long" ] => subject_of("S", notions: long.(601)),
          [ "courses[0].subjects[0].exercises", "blank" ] => subject_of("S", exercises: 0)
        }
        cases.each do |pair, bounded|
          assert_equal [ pair ], pairs(validate(lesson(subjects: [ bounded ]))), pair.inspect
        end
        edge = subject_of("S", notions: long.(600)).tap { it["exercises"][0]["hint"] = long.(400); it["title"] = long.(200) }
        assert validate(lesson(subjects: [ edge ])).valid?
        too_long_notion_hint = revision_notion("Simplifier").tap { it["exercise"]["hint"] = long.(401) }
        assert_equal [ [ "courses[0].notions[0].exercise.hint", "too_long" ] ], pairs(validate(lesson(notions: [ too_long_notion_hint ])))
        assert_equal 0, tree_counts.sum
      end

      test "more than 10 subjects, or more than 10 exercises in a subject, are refused with a named error" do
        many = validate(lesson(subjects: Array.new(11) { subject_of("S#{it}", exercises: 1) }))
        assert_equal [ [ "courses[0].subjects", ImportCourseTree::TOO_MANY_SUBJECTS ] ], pairs(many)
        assert_equal({ course: "Racines carrées", max: 10 }, many.errors.first.params)
        assert validate(lesson(subjects: Array.new(10) { subject_of("S#{it}", exercises: 1) })).valid?

        long = validate(lesson(subjects: [ subject_of("Sujet 1 · Thalès", exercises: 11) ]))
        assert_equal [ [ "courses[0].subjects[0].exercises", ImportCourseTree::TOO_MANY_SUBJECT_EXERCISES ] ], pairs(long)
        assert_equal({ subject: "Sujet 1 · Thalès", max: 10 }, long.errors.first.params)
        assert validate(lesson(subjects: [ subject_of("S", exercises: 10) ])).valid?
        assert_equal 0, tree_counts.sum
      end

      test "a key of an unexpected type is refused, never converted" do
        typed = ->(subject) { pairs(validate(lesson(subjects: [ subject ]))) }

        assert_equal [ [ "courses[0].subjects", "schema" ] ], pairs(validate(lesson(subjects: "Sujet 1")))
        assert_equal [ [ "courses[0].subjects", "schema" ] ], pairs(validate(lesson(subjects: { "title" => "S" })))
        assert_equal [ [ "courses[0].subjects[0]", "schema" ] ], typed.([ "Sujet 1" ])
        assert_equal [ [ "courses[0].subjects[0].title", "schema" ] ], typed.(subject_of("S").merge("title" => 12))
        assert_equal [ [ "courses[0].subjects[0].title", "schema" ] ], typed.(subject_of("S").merge("title" => [ "S" ]))
        assert_equal [ [ "courses[0].subjects[0].notions", "schema" ] ], typed.(subject_of("S").merge("notions" => { "a" => 1 }))
        assert_equal [ [ "courses[0].subjects[0].exercises", "schema" ] ], typed.(subject_of("S").merge("exercises" => "x"))
        assert_equal [ [ "courses[0].subjects[0].exercises[0]", "schema" ] ], typed.(subject_of("S").merge("exercises" => [ 3 ]))
        hint = ->(value) { subject_of("S").tap { it["exercises"][0]["hint"] = value } }
        [ 5, [ "x" ], { "a" => 1 }, true ].each do |value|
          assert_equal [ [ "courses[0].subjects[0].exercises[0].hint", "schema" ] ], typed.(hint.(value)), value.inspect
        end
        assert_equal [ [ "courses[0].subjects[0].exercises", "blank" ] ], typed.(subject_of("S").except("exercises"))
        assert validate(lesson(subjects: nil)).valid?
        assert validate(lesson(subjects: [])).valid?
        assert typed.(hint.(nil)).empty?
        assert_equal 0, tree_counts.sum
      end

      test "a trapped text is stored raw and rendered escaped, never html_safe" do
        trap = "<script>alert('x')</script><b>gras</b>"
        subject = subject_of(trap, notions: trap).tap { it["exercises"][0]["hint"] = trap }
        write_item(validate(lesson(subjects: [ subject ])))

        stored = Orm::Subject.first
        hint = Orm::Exercise.where.not(hint: nil).pick(:hint)
        assert_equal [ trap, trap, trap ], [ stored.title, stored.notions, hint ]
        assert_equal [ false, false, false ], [ stored.title, stored.notions, hint ].map(&:html_safe?)
        html = ApplicationController.render(inline: "<p><%= title %></p><p><%= notions %></p><p><%= hint %></p>",
                                            locals: { title: stored.title, notions: stored.notions, hint: })
        assert_not_includes html, "<script>"
        assert_not_includes html, "<b>"
        assert_equal 3, html.scan("&lt;script&gt;").size
        files = %w[app/domain/use_cases/catalog/import_course_tree.rb app/infrastructure/repositories/catalog/content_tree_writer.rb]
        source = files.flat_map { Rails.root.join(it).readlines }.reject { it.strip.start_with?("#") }.join
        assert_not source.match?(/html_safe|\braw\(/), "le texte importé ne doit jamais être marqué sûr"
      end

      # CA-9, de bout en bout par RunImport (schéma, adaptateur, moteur, base)
      test "the Thalès lesson with hints and 3 subjects is imported by the engine, in draft, and the report counts the subjects" do
        report = run_import(revision_thales_document)

        assert_equal [ "completed", 1, 1, 0 ], report.values_at(:status, :total_count, :imported_count, :error_count)
        assert_equal({ "essentials_created" => 2, "exercises_created" => 18, "questions_created" => 90, "answers_created" => 180,
                       "subjects_created" => 3 }, report.details)
        course = Orm::Course.find_by!(slug: "thales")
        assert_equal [ "Sujet 1 · Thalès", "Sujet 2 · Thalès", "Sujet 3 · Thalès" ], course.subjects.order(:position).pluck(:title)
        assert_equal [ "Théorème de Thalès · proportionnalité" ], course.subjects.pluck(:notions).uniq
        assert_equal [ 4, 4, 4 ], course.subjects.order(:position).map { it.exercises.count }
        assert_equal [ "Sujet 3 · Thalès · exercice 1", "Sujet 3 · Thalès · exercice 4" ],
                     course.subjects.find_by!(position: 3).exercises.pluck(:title).values_at(0, 3)
        assert_equal [ "Commence par repérer les deux droites parallèles." ], Orm::Exercise.where(course_id: course.id).where.not(hint: nil).pluck(:hint).uniq
        assert_equal 2, Orm::Exercise.where(course_id: course.id).where.not(hint: nil).count
        assert_equal [ nil ], Orm::Exercise.where.not(subject_id: nil).pluck(:essential_id).uniq
        assert_equal [ "draft" ], Orm::Exercise.distinct.pluck(:status)
      end

      test "a lesson without subject keeps its report as before, a reimport replaces the subjects and recounts them" do
        assert_equal({ "essentials_created" => 2, "exercises_created" => 6, "questions_created" => 30, "answers_created" => 60 },
                     run_import(revision_thales_document(subjects: [])).details)
        report = run_import(revision_thales_document(subjects: [ revision_subject("Sujet unique", exercises: 2) ]))

        assert_equal [ "completed", true ], [ report.status, report.details.key?("subjects_created") ]
        assert_equal [ 1, [ "Sujet unique" ] ], [ report.details["subjects_created"], Orm::Subject.pluck(:title) ]
        assert_equal 2 + 4 + 2, Orm::Exercise.count
      end

      # CA-9
      test "a subject exercise with a notion is refused by the engine, the error names the subject and nothing is written" do
        document = revision_thales_document
        document["courses"].first["subjects"][1]["exercises"][2]["notion"] = "Théorème de Thalès"

        report = run_import(document)

        assert_equal [ "completed", 0, 1 ], report.values_at(:status, :imported_count, :error_count)
        assert_equal [ [ "courses[0].subjects[1].exercises[2].notion", "subject_exercise_with_notion" ] ], report_pairs(report)
        assert_equal({ "subject" => "Sujet 2 · Thalès" }, report.import_errors.first["params"])
        error = Entities::Catalog::ImportError.new(path: "courses[0]", code: "subject_exercise_with_notion", params: { subject: "Sujet 2 · Thalès" })
        assert_includes ApplicationController.helpers.extend(Teams::ImportsHelper).import_error_message(error), "Sujet 2 · Thalès"
        assert_equal [ 0, 0, 0, 0, 0, 0 ], tree_counts + [ Orm::Subject.count ]
      end

      test "the engine refuses a wrong type, a long text and too many subjects with a named error, and writes nothing" do
        typed = revision_thales_document
        typed["courses"].first["subjects"][0]["exercises"][0]["hint"] = 5
        assert_equal [ [ "courses[0].subjects[0].exercises[0].hint", "schema" ] ], report_pairs(run_import(typed))

        long = revision_thales_document
        long["courses"].first["notions"][0]["exercise"]["hint"] = "é" * 401
        assert_equal [ [ "courses[0].notions[0].exercise.hint", "too_long" ] ], report_pairs(run_import(long))

        many = revision_thales_document(subjects: Array.new(11) { revision_subject("S#{it}", exercises: 1) })
        report = run_import(many)
        assert_equal [ [ "courses[0].subjects", "too_many_subjects" ] ], report_pairs(report)
        assert_equal({ "course" => "Thalès", "max" => 10 }, report.import_errors.first["params"])

        wide = revision_thales_document(subjects: [ revision_subject("Sujet large", exercises: 11) ])
        report = run_import(wide)
        assert_equal [ [ "courses[0].subjects[0].exercises", "too_many_subject_exercises" ] ], report_pairs(report)
        assert_equal({ "subject" => "Sujet large", "max" => 10 }, report.import_errors.first["params"])
        assert_equal [ 0, 0, 0, 0, 0, 0 ], tree_counts + [ Orm::Subject.count ]
      end

      # CA-11
      test "a draft lesson is replaced whole, keeps its id and slug, and loses the team sessions on its old exercises" do
        run_import(envelope(lesson))
        course = Orm::Course.find_by!(slug: "racines-carrees")
        old_exercise = Orm::Exercise.where(course_id: course.id).order(:position).first
        create_attempt(session: create_exercise_session(student: @author, exercise: old_exercise), question: old_exercise.questions.first)
        corrected = lesson_of_three
        corrected["notions"][0]["remember"] = "Un énoncé corrigé."

        report = run_import(envelope(corrected))

        assert_equal [ "completed", 1, 0 ], report.values_at(:status, :imported_count, :error_count)
        assert_equal({ "essentials_created" => 3, "exercises_created" => 7, "questions_created" => 35, "answers_created" => 70 }, report.details)
        assert_equal [ 1, 3, 7, 35, 70 ], tree_counts
        replaced = Orm::Course.find_by!(slug: "racines-carrees")
        assert_equal [ course.id, "draft" ], [ replaced.id, replaced.status ]
        assert_equal "Un énoncé corrigé.", replaced.essentials.order(:position).first.sheet["remember"]
        assert_equal 2, replaced.figures.size
        assert_not Orm::Exercise.exists?(old_exercise.id)
        assert_equal [ 0, 0 ], [ Orm::ExerciseSession.count, Orm::QuestionAttempt.count ]
        assert_equal [ "draft" ], Orm::Exercise.distinct.pluck(:status)
      end
    end
  end
end
