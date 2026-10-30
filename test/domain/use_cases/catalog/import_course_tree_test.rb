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

      def adapter(writer: Repositories::Catalog::ContentTreeWriter.new)
        ImportCourseTree.new(courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
                             taxonomy: Repositories::Catalog::TaxonomyRepository.new, writer:)
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

      # CA-3
      test "a notion without exercise, or with two, is refused and the report names the notion" do
        missing = lesson
        missing["notions"][1].delete("exercise")
        two = lesson("name" => "Autre")
        two["notions"][0]["exercise"] = [ two["notions"][0]["exercise"], two["notions"][0]["exercise"] ]

        report = run_import(envelope(missing, two))

        assert_equal [ 0, 2 ], report.values_at(:imported_count, :error_count)
        assert_equal [ [ "courses[0].notions[1].exercise", "essential_exercise_count" ], [ "courses[1].notions[0].exercise", "essential_exercise_count" ] ],
                     report_pairs(report)
        assert_equal [ 0, 0, 0, 0, 0 ], tree_counts
        item = validate(missing)
        assert_equal({ course: "Racines carrées", name: "Calculer avec des racines", count: 0 }, item.errors.first.params)
        assert_equal 2, validate(two).errors.first.params[:count]
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
