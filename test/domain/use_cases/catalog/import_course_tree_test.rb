require "test_helper"

# CA-08, CA-26, CA-27, CA-28, ADR-0039, ADR-0113: the course tree adapter on the real engine and repositories, with the development referential
# (seed_referential). A course arrives with all its descendants, in draft, or not at all.
module UseCases
  module Catalog
    class ImportCourseTreeTest < ActiveSupport::TestCase
      # The base refuses every batch holding the course named `fragile` (a slug taken between validation and write).
      class FragileWriter < Repositories::Catalog::ContentTreeWriter
        def initialize(fragile:)
          super()
          @fragile = fragile
        end

        def write(courses: [], **)
          raise ActiveRecord::RecordNotUnique, "refus simulé" if courses.any? { it.name == @fragile }

          super
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
        @referential = seed_referential
        @author = create_team_member(team_role: "content", second_factor: false)
      end

      def adapter(writer: Repositories::Catalog::ContentTreeWriter.new)
        ImportCourseTree.new(courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
                             taxonomy: Repositories::Catalog::TaxonomyRepository.new, writer:)
      end

      # The real engine, on a report in base and its file.
      def run_import(*documents, adapter: self.adapter, transaction: Repositories::Shared::Transaction.new, author: @author)
        report = create_import_report(kind: "course_tree", imported_by: author)
        files = documents.each_with_index.map { |document, index| import_upload(io: StringIO.new(document.is_a?(String) ? document : document.to_json), filename: "cours-#{index}.json") }
        Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files:)
        @result = UseCases::Catalog::RunImport.new(
          adapter:, reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
          schema: Repositories::Catalog::ImportSchemaValidator.new, users: Repositories::Identity::UserRepository.new,
          audit_log: Repositories::Identity::AuditLogRepository.new, transaction:, clock: Time.zone
        ).call(report_id: report.id)
        report.reload
      end

      def document(*courses, version: 2) = { "format" => "lnclass.course-tree", "version" => version, "courses" => courses }

      # Format 2 : une notion, son exercice, et les quatre exercices de toute la leçon.
      def course(name = "Génétique et Évolution", **overrides)
        course_tree_v2_document(courses: 1, essentials: 1, questions: 2, answers: 3)
          .fetch("courses").first.merge("name" => name, **overrides.transform_keys(&:to_s))
      end

      # Format 1 : ses exercices sont ceux des notions seulement.
      def v1_course(name = "Génétique et Évolution", **overrides)
        course_tree_document(courses: 1, essentials: 1, exercises: 1, questions: 2, answers: 3)
          .fetch("courses").first.merge("name" => name, **overrides.transform_keys(&:to_s))
      end

      def validate(root)
        subject = adapter
        subject.validate_root(root:, path: "courses[0]", context: subject.prepare(target: nil))
      end

      def error_pairs(item) = item.errors.map { [ it.path, it.code ] }
      def exercises_of(course) = Orm::Exercise.where(course_id: course.id)
      def id_of(kind, slug) = @referential.fetch(kind).fetch(slug).id

      def tree_counts
        [ Orm::Course, Orm::Essential, Orm::Exercise, Orm::Question, Orm::Answer ].map(&:count)
      end

      test "honours the importer contract, and validate_root writes nothing" do
        subject = adapter
        assert_importer_contract ImportCourseTree, adapter: subject, root: course, context: subject.prepare(target: nil)
        assert_equal ImportCourseTree::POLICY, Entities::Catalog::ImportKind.fetch(ImportCourseTree::KIND).policy
        assert_equal Policies::Catalog::ManageContentPolicy, ImportCourseTree::POLICY
      end

      test "there is no target: the envelope is enough" do
        result = adapter.resolve_target(document: { "course" => "ignore" })

        assert result.success?
        assert_nil result.value
      end

      test "a valid course is planned with its descendants: slugs, public ids, positions, and its duplicate key" do
        root = course("  Génétique   et Évolution ", subtitle: " Hérédité ", level_name: "Tle", series_name: "D",
                      material_name: "Physique Chimie", essentials: [ course.fetch("essentials").first,
                                                                        course.fetch("essentials").first.merge("name" => "Fiche 2") ])
        item = validate(root)

        assert item.valid?
        node = item.plan
        assert_equal [ "genetique-et-evolution", "Génétique et Évolution", "Hérédité" ], [ node.slug, node.name, node.subtitle ]
        assert_equal [ id_of(:levels, "tle"), id_of(:series, "d"), id_of(:materials, "physique-chimie") ],
                     [ node.level_id, node.series_id, node.material_id ]
        assert_equal [ "genetiqueetevolution", id_of(:levels, "tle"), id_of(:materials, "physique-chimie"), id_of(:series, "d") ], item.key
        assert_equal [ [ "genetique-et-evolution-fiche-1", 1 ], [ "genetique-et-evolution-fiche-2", 2 ] ],
                     node.essentials.map { [ it.slug, it.position ] }
        exercise = node.essentials.first.exercises.first
        assert_equal [ 14, "fixation", "Consigne 1" ], [ exercise.public_id.length, exercise.exercise_type, exercise.statement ]
        assert_not_equal exercise.public_id, node.essentials.last.exercises.first.public_id
        assert_equal [ "Bilan 1", "Bilan 2", "Bilan 3", "Bilan 4" ], node.exercises.map(&:title)
        assert_equal [ nil ], node.exercises.map(&:essential_id).uniq
        assert_equal "Consigne 2", node.exercises.second.statement
        assert_equal [ [ 1, "Question 1" ], [ 2, "Question 2" ] ], exercise.questions.map { [ it.position, it.content ] }
        assert_equal [ [ 1, true ], [ 2, false ], [ 3, false ] ], exercise.questions.first.answers.map { [ it.position, it.correct ] }
      end

      test "the old application keys are read: nom, sous_titre, is_correct; status is ignored" do
        root = course(nil, nom: "Optique", sous_titre: "Lumière", status: "publié", series_name: nil)
        root.delete("name")
        root.delete("subtitle")
        exercise = root["essentials"][0]["exercises"][0]
        exercise["questions"][0]["answers"] = [ { "content" => "Oui", "is_correct" => true }, { "content" => "Non" },
                                                { "content" => "Peut-être", "is_correct" => false } ]
        exercise["questions"][1]["explanation"] = "  Parce que.  "

        node = validate(root).plan

        assert_equal [ "Optique", "Lumière", nil ], [ node.name, node.subtitle, node.series_id ]
        planned = node.essentials.first.exercises.first
        assert_equal "Exercice 1", planned.title
        assert_equal [ true, false, false ], planned.questions.first.answers.map(&:correct)
        assert_equal [ nil, "Parce que." ], planned.questions.map(&:explanation)
        assert_equal [ "optique", id_of(:levels, "tle"), id_of(:materials, "svt"), nil ], validate(root).key
      end

      test "a name without latin letter still gets a slug, and a slug taken in base or in the file gets a suffix" do
        create_course(name: "Génétique", level: Orm::Level.find_by!(slug: "1ere"), material: Orm::Material.find_by!(slug: "svt"))
        subject = adapter
        context = subject.prepare(target: nil)

        first = subject.validate_root(root: course("Génétique"), path: "courses[0]", context:).plan
        second = subject.validate_root(root: course("Génétique", level_name: "2nde", series_name: "C"), path: "courses[1]", context:).plan
        greek = subject.validate_root(root: course("π", essentials: [ course["essentials"][0].merge("name" => "∑") ]),
                                      path: "courses[2]", context:).plan

        assert_equal [ "genetique-2", "genetique-3", "course" ], [ first.slug, second.slug, greek.slug ]
        assert_equal [ "genetique-fiche-1", "genetique-fiche-1-2", "essential" ],
                     [ first.essentials.first.slug, second.essentials.first.slug, greek.essentials.first.slug ]
      end

      test "the referential is resolved, never created: unknown level, material, series, or a series not offered" do
        item = validate(course(level_name: "Terminale", material_name: "Astronomie", series_name: "Z"))
        assert_equal [ [ "courses[0].level_name", "unknown_level" ], [ "courses[0].material_name", "unknown_material" ],
                       [ "courses[0].series_name", "unknown_series" ] ], error_pairs(item)
        assert_nil item.plan

        assert_equal [ [ "courses[0].series_name", "series_not_allowed" ] ], error_pairs(validate(course(level_name: "3ème")))
        assert_equal [ 7, 5, 6 ], [ Orm::Level.count, Orm::Series.count, Orm::Material.count ]
      end

      test "two essentials of one course with the same name: the second is in error at its path" do
        essential = course["essentials"].first
        item = validate(course(essentials: [ essential, essential.merge("name" => "  FICHE 1 "), essential.merge("name" => "") ]))

        assert_equal [ [ "courses[0].essentials[2].name", "blank" ], [ "courses[0].essentials[1].name", "invalid_value" ] ],
                     error_pairs(item)
        assert_equal({ value: "  FICHE 1 " }, item.errors.last.params)
      end

      test "a full course is written in draft, whatever its status, by the importing author" do
        report = run_import(document(course("Génétique", status: "publié", material_name: "Physique Chimie", essentials: []),
                                     course("Écologie", status: "published")))

        assert_equal [ "completed", 2, 2, 0, 0 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal({ "essentials_created" => 1, "exercises_created" => 9, "questions_created" => 18, "answers_created" => 54 },
                     report.details)
        assert_equal [ 2, 1, 9, 18, 54 ], tree_counts
        assert_equal "physique-chimie", Orm::Course.find_by!(name: "Génétique").material.slug
        [ Orm::Course, Orm::Essential, Orm::Exercise ].each do |model|
          assert_equal [ [ "draft", @author.id, nil ] ], model.distinct.pluck(:status, :author_id, :published_at), model
        end
        assert_equal "<p>Cours 1</p>", Orm::Course.find_by!(name: "Écologie").content.body.to_html
      end

      # CA-14, ADR-0091 §4.5 : tolerance et match s'importent aussi par les cours complets.
      test "tolerance and match are imported with the course tree" do
        node = course("Nouveaux types")
        node["essentials"][0]["exercises"][0]["questions"] = [
          { "content" => "Combien ?", "question_type" => "numeric", "tolerance" => 0.5, "answers" => [ { "content" => "3" } ] },
          { "content" => "Relie.", "question_type" => "matching", "answers" => %w[a b c].map { { "content" => it, "match" => it.upcase } } }
        ]

        report = run_import(document(node))

        assert_equal [ 1, 0 ], report.values_at(:imported_count, :error_count)
        assert_equal BigDecimal("0.5"), Orm::Question.find_by!(question_type: "numeric").numeric_tolerance
        assert_equal %w[A B C], Orm::Question.find_by!(question_type: "matching").answers.order(:position).pluck(:match_content)
      end

      test "an error deep in the tree is reported at its exact path, and its course leaves no row" do
        courses = course_tree_v2_document(courses: 4, essentials: 2, questions: 3, answers: 4)["courses"]
        courses[3]["essentials"][1]["exercises"][0]["questions"][2]["answers"].each { it["correct"] = true }

        report = run_import(document(*courses))

        assert_equal [ "completed", 4, 3, 0, 1 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ { "path" => "courses[3].essentials[1].exercises[0].questions[2].answers", "code" => "question_structure",
                         "params" => { "rule" => "wrong_correct_count" } } ], report.import_errors
        assert_not Orm::Course.exists?(name: "Cours 4")
        assert_equal [ 3, 6, 18, 54, 216 ], tree_counts
      end

      test "version 1 duplicates in base and in the file are skipped and counted; the existing course is not modified" do
        existing = create_course(name: "Génétique et Évolution", level: Orm::Level.find_by!(slug: "tle"),
                                 material: Orm::Material.find_by!(slug: "svt"), series: Orm::Series.find_by!(slug: "d"))
        before = existing.reload.attributes

        report = run_import(document(v1_course("GENETIQUE et evolution"), v1_course("Génétique  etÉvolution", series_name: "C"),
                                     v1_course("Écologie"), v1_course("écologie "), version: 1))

        assert_equal [ 4, 2, 2, 0 ], report.values_at(:total_count, :imported_count, :skipped_count, :error_count)
        assert_equal before, existing.reload.attributes
        assert_equal 0, existing.essentials.count
        assert_equal [ "c" ], Orm::Course.where.not(id: existing.id).where("name ILIKE 'Génétique%'").map { it.series.slug }
      end

      test "a mixed file gives an exact report, and invalid courses leave no row at all" do
        existing = existing_lesson(name: "Cours 8")
        mixed = course_tree_v2_document(courses: 10, essentials: 2, questions: 4, answers: 3)
        mixed["courses"][1]["essentials"][0]["exercises"][0]["questions"][3]["answers"].first(2).each { it["correct"] = true }
        mixed["courses"][4]["material_name"] = "Astronomie"

        report = run_import(mixed)

        assert_equal [ "completed", 10, 8, 0, 2 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ [ "courses[1].essentials[0].exercises[0].questions[3].answers", "question_structure" ],
                       [ "courses[4].material_name", "unknown_material" ] ], report.import_errors.map { it.values_at("path", "code") }
        assert_equal [ "Cours 1", "Cours 3", "Cours 4", "Cours 6", "Cours 7", "Cours 8", "Cours 9", "Cours 10" ].sort,
                     Orm::Course.pluck(:name).sort
        assert_equal 2, existing.essentials.count
        assert_equal [ 8, 7 * 2 + 2, 8 * 6, 8 * 24, 8 * 72 ], tree_counts
        assert_equal({ "essentials_created" => 14, "exercises_created" => 48, "questions_created" => 192, "answers_created" => 576 },
                     report.details)
      end

      test "the mixed helper file: invalid names and in-file duplicates are counted, nothing invalid is written" do
        report = run_import(mixed(course_tree_v2_document(courses: 9, essentials: 1, questions: 1, answers: 2)))

        assert_equal [ "completed", 9, 6, 1, 2 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ [ "courses[3].name", "blank" ], [ "courses[7].name", "blank" ] ], report.import_errors.map { it.values_at("path", "code") }
        assert_equal [ 6, 6, 30, 30, 60 ], tree_counts
      end

      test "an answer longer than the column is refused by the schema, at its path" do
        long = course("Long")
        long["essentials"][0]["exercises"][0]["questions"][1]["answers"][2]["content"] = "a" * 501

        report = run_import(document(long, course("Court")))

        assert_equal [ 2, 1, 1 ], report.values_at(:total_count, :imported_count, :error_count)
        assert_equal [ [ "courses[0].essentials[0].exercises[0].questions[1].answers[2].content", "schema" ] ],
                     report.import_errors.map { it.values_at("path", "code") }
      end

      # ADR-0105 §4.3, §4.6 : l'import annonce les images, il n'en crée aucune.
      test "an image slot in a sheet and an image description on a question are written as they are" do
        illustrated = course("Le circuit électrique")
        essential = illustrated["essentials"][0]
        essential["content"] = "<h2>Le circuit</h2><p>[[image: une pile reliée à une lampe]]</p><p>Texte.</p>"
        essential["exercises"][0]["questions"][1]["image"] = { "description" => "  un interrupteur ouvert  " }

        report = run_import(document(illustrated))

        assert_equal [ "completed", 1, 0 ], report.values_at(:status, :imported_count, :error_count)
        written = Orm::Essential.joins(:course).find_by!(courses: { name: "Le circuit électrique" })
        assert_includes written.content.body.to_html, "<p>[[image: une pile reliée à une lampe]]</p>"
        assert_equal [ "une pile reliée à une lampe" ], Entities::Catalog::ImageSlot.scan(written.content.body.to_html).map(&:description)
        assert_equal [ nil, "un interrupteur ouvert" ], written.exercises.first.questions.order(:position).pluck(:image_description)
        assert_equal 0, Orm::QuestionImage.count
      end

      # Menace n° 13 : le plafond de 200 Ko du texte d'une fiche est celui du schéma, au caractère près.
      test "a sheet text of exactly 204,800 characters is imported, 204,801 is refused by the schema at its path" do
        limit = Entities::Catalog::Essential::CONTENT_MAX
        exact = course("Exact")
        exact["essentials"][0]["content"] = "a" * limit
        over = course("Dépassé")
        over["essentials"][0]["content"] = "a" * (limit + 1)

        report = run_import(document(exact, over))

        assert_equal 204_800, limit
        assert_equal [ 2, 1, 1 ], report.values_at(:total_count, :imported_count, :error_count)
        assert_equal [ [ "courses[1].essentials[0].content", "schema" ] ], report.import_errors.map { it.values_at("path", "code") }
        assert_equal limit, Orm::Essential.joins(:course).find_by!(courses: { name: "Exact" }).content.body.to_plain_text.length
      end

      # Menace n° 13 : un texte trop complexe à relire est refusé à son chemin avec son propre code, et journalisé sans son contenu.
      test "a sheet text too complex to read is refused with its own code, and the report is logged without the content" do
        hostile = course("Hostile")
        hostile["essentials"][0]["content"] = %(<span title="<p>">x</span>) * 7_000

        logs = capture_log { @report = run_import(document(hostile, course("Simple"))) }

        assert_equal [ 2, 1, 1 ], @report.values_at(:total_count, :imported_count, :error_count)
        assert_equal [ [ "courses[0].essentials[0].content", "image_slots_unreadable" ] ], @report.import_errors.map { it.values_at("path", "code") }
        assert_includes logs, "[ImportReportRepository] image_slots_unreadable report=#{@report.id} paths=[\"courses[0].essentials[0].content\"]"
        assert_not_includes logs, "span title"
      end

      test "an image description empty, blank, too long, missing, with an unknown key, or an image not an object is refused at its path" do
        cases = { "" => "schema", "   " => "blank", "a" * 151 => "schema" }.map do |description, code|
          [ { "description" => description }, code, "courses[0].essentials[0].exercises[0].questions[0].image.description" ]
        end
        cases << [ { "description" => "une pile", "url" => "https://x" }, "schema", "courses[0].essentials[0].exercises[0].questions[0].image.url" ]
        cases << [ "une pile", "schema", "courses[0].essentials[0].exercises[0].questions[0].image" ]
        cases << [ {}, "schema", "courses[0].essentials[0].exercises[0].questions[0].image.description" ]

        cases.each do |image, code, path|
          broken = course("Cassé")
          broken["essentials"][0]["exercises"][0]["questions"][0]["image"] = image

          report = run_import(document(broken))

          assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count), image.inspect
          assert_equal [ [ path, code ] ], report.import_errors.map { it.values_at("path", "code") }, image.inspect
        end
        assert_equal 0, Orm::Course.count
      end

      test "a version 3 envelope is rejected in bloc, with zero writes" do
        report = run_import(course_tree_v2_document(courses: 3).merge("version" => 3))

        assert_equal "rejected", report.status
        assert_equal [ [ "version", "version_unsupported" ] ], report.import_errors.map { it.values_at("path", "code") }
        assert_equal [ 2 ], report.import_errors.map { it["params"]["expected"] }
        assert_equal [ 0, 0, 0, 0, 0 ], tree_counts
      end

      test "a batch refused by the base is replayed course by course, and only the refused one is in error" do
        transaction = CountingTransaction.new

        report = run_import(document(course("Solide"), course("Fragile"), course("Robuste")),
                            adapter: adapter(writer: FragileWriter.new(fragile: "Fragile")), transaction:)

        assert_equal [ "completed", 3, 2, 1 ], report.values_at(:status, :total_count, :imported_count, :error_count)
        assert_equal [ { "path" => "courses[1]", "code" => "write_failed", "params" => {} } ], report.import_errors
        assert_equal 1 + 3, transaction.attempts
        assert_equal %w[Robuste Solide], Orm::Course.order(:name).pluck(:name)
        assert_equal [ 2, 2, 10, 20, 60 ], tree_counts
        assert_equal 20, report.details["questions_created"]
      end

      # CA-26, ADR-0113 §4.4 : la leçon, ses notions et ses exercices arrivent ensemble, en brouillon.
      test "CA-26 a lesson with 4 notions, 4 notion exercises and 4 lesson-wide exercises is imported with its subjects" do
        report = run_import(course_tree_v2_document(courses: 1, essentials: 4))

        assert_equal [ "completed", 1, 0 ], report.values_at(:status, :imported_count, :error_count)
        assert_equal({ "essentials_created" => 4, "exercises_created" => 8, "questions_created" => 16, "answers_created" => 48 }, report.details)
        lesson = Orm::Course.find_by!(name: "Cours 1")
        assert_equal [ "draft" ], Orm::Exercise.distinct.pluck(:status)
        assert_equal [ 1, 2, 3, 4, 5, 6, 7, 8 ], exercises_of(lesson).order(:position).pluck(:position)
        assert_equal lesson.essentials.order(:position).pluck(:id), exercises_of(lesson).where.not(essential_id: nil).order(:position).pluck(:essential_id)
        wide = exercises_of(lesson).where(essential_id: nil).order(:position)
        assert_equal [ "Bilan 1", "Bilan 2", "Bilan 3", "Bilan 4" ], wide.pluck(:title)
        assert_equal [ lesson.id ], wide.pluck(:course_id).uniq
        assert_equal [ "Consigne 1", "Consigne 2", "Consigne 3", "Consigne 4" ], wide.pluck(:statement)
        assert_equal [ "Consigne 1" ], lesson.essentials.first.exercises.pluck(:statement)
      end

      # CA-27 : la leçon est refusée entière, la notion nommée.
      test "CA-27 a notion without exercise refuses the whole lesson and names the lesson and the notion" do
        broken = course("Thalès", essentials: [ course["essentials"].first, course["essentials"].first.merge("name" => "Réciproque", "exercises" => []) ])

        report = run_import(document(broken, course("Pythagore")))

        assert_equal [ "completed", 2, 1, 1 ], report.values_at(:status, :total_count, :imported_count, :error_count)
        assert_equal [ { "path" => "courses[0].essentials[1].exercises", "code" => "essential_exercise_count",
                         "params" => { "course" => "Thalès", "name" => "Réciproque", "count" => 0 } } ], report.import_errors
        assert_not Orm::Course.exists?(name: "Thalès")
        assert_equal [ 1, 1, 5 ], [ Orm::Course.count, Orm::Essential.count, Orm::Exercise.count ]
      end

      test "CA-27 two exercises on one notion are refused too" do
        essential = course["essentials"].first
        broken = course("Thalès", essentials: [ essential.merge("exercises" => essential["exercises"] * 2) ])

        item = validate(broken)

        assert_equal [ [ "courses[0].essentials[0].exercises", "essential_exercise_count" ] ], error_pairs(item)
        assert_equal 2, item.errors.first.params[:count]
        assert_nil item.plan
      end

      test "CA-27 anything but four lesson-wide exercises refuses the lesson, with the count received" do
        [ 0, 3, 5 ].each do |count|
          broken = course("Thalès")
          broken["exercises"] = Array.new(count) { |index| broken["exercises"][index % 4] }

          report = run_import(document(broken))

          assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count), count
          assert_equal [ { "path" => "courses[0].exercises", "code" => "lesson_exercise_count", "params" => { "course" => "Thalès", "count" => count, "expected" => 4 } } ],
                       report.import_errors, count
        end
        assert_equal 0, Orm::Course.count
      end

      test "CA-27 a lesson without the exercises key counts zero" do
        broken = course("Thalès")
        broken.delete("exercises")

        assert_equal [ [ "courses[0].exercises", "lesson_exercise_count" ] ], error_pairs(validate(broken))
      end

      test "both rules are reported together, and the other errors of the lesson with them" do
        broken = course("Thalès", essentials: [ course["essentials"].first.merge("exercises" => []) ], exercises: [])

        assert_equal [ [ "courses[0].essentials[0].exercises", "essential_exercise_count" ], [ "courses[0].exercises", "lesson_exercise_count" ] ],
                     error_pairs(validate(broken)).sort
      end

      test "the subject is required, notion exercise or lesson-wide exercise" do
        broken = course
        broken["essentials"][0]["exercises"][0]["statement"] = "   "
        broken["exercises"][2].delete("statement")

        assert_equal [ [ "courses[0].essentials[0].exercises[0].statement", "blank" ], [ "courses[0].exercises[2].statement", "blank" ] ],
                     error_pairs(validate(broken))
      end

      test "a lesson-wide exercise is checked like any exercise: type, title, questions" do
        broken = course
        broken["exercises"][0]["exercise_type"] = "quiz"
        broken["exercises"][1]["title"] = ""
        broken["exercises"][2]["questions"] = []
        broken["exercises"][3]["questions"][0]["answers"].each { it["correct"] = true }

        assert_equal [ [ "courses[0].exercises[0].exercise_type", "invalid_value" ], [ "courses[0].exercises[1].title", "blank" ],
                       [ "courses[0].exercises[2].questions", "blank" ], [ "courses[0].exercises[3].questions[0].answers", "question_structure" ] ],
                     error_pairs(validate(broken))
      end

      test "the format 2 schema refuses the old exercise keys: description and name" do
        broken = course
        broken["exercises"][0]["description"] = "Ancienne consigne"
        broken["essentials"][0]["exercises"][0]["name"] = "Ancien titre"

        report = run_import(document(broken))

        assert_equal [ [ "courses[0].essentials[0].exercises[0].name", "schema" ], [ "courses[0].exercises[0].description", "schema" ] ],
                     report.import_errors.map { it.values_at("path", "code") }.sort
      end

      # CA-28 : la leçon et ses notions entrent ; les exercices de la v1 ne sont pas lus.
      test "CA-28 a version 1 file imports the lesson and its notions, ignores its exercises and warns" do
        invalid_but_ignored = v1_course("Optique")
        invalid_but_ignored["essentials"][0]["exercises"] << { "title" => "Sans question", "exercise_type" => "fixation", "questions" => [] }

        report = run_import(document(v1_course("Génétique", essentials: [ v1_course["essentials"].first, v1_course["essentials"].first.merge("name" => "Fiche 2") ]),
                                     invalid_but_ignored, version: 1))

        assert_equal [ "completed", 2, 2, 0 ], report.values_at(:status, :total_count, :imported_count, :error_count)
        assert_equal({ "essentials_created" => 3, "exercises_created" => 0, "questions_created" => 0, "answers_created" => 0,
                       "exercises_ignored_v1" => 4 }, report.details)
        assert_equal [ 2, 3, 0 ], [ Orm::Course.count, Orm::Essential.count, Orm::Exercise.count ]
      end

      test "a version 1 file without exercise gives no warning" do
        report = run_import(document(v1_course("Génétique", essentials: [ v1_course["essentials"].first.merge("exercises" => []) ]), version: 1))

        assert_equal [ "completed", 1 ], report.values_at(:status, :imported_count)
        assert_not report.details.key?("exercises_ignored_v1")
      end

      test "a version 1 file is still checked by its own schema: a subject key is unknown to it" do
        broken = v1_course
        broken["essentials"][0]["exercises"][0]["statement"] = "Sujet"

        report = run_import(document(broken, version: 1))

        assert_equal [ [ "courses[0].essentials[0].exercises[0].statement", "schema" ] ], report.import_errors.map { it.values_at("path", "code") }
      end

      test "a version 1 file and a version 2 file in one envoi: each keeps its own rules" do
        report = run_import(document(v1_course("Ancien"), version: 1), document(course("Nouveau")))

        assert_equal [ "completed", 2, 0 ], report.values_at(:status, :imported_count, :error_count)
        assert_equal 1, report.details["exercises_ignored_v1"]
        assert_equal [ 0, 5 ], [ exercises_of(Orm::Course.find_by!(name: "Ancien")).count, exercises_of(Orm::Course.find_by!(name: "Nouveau")).count ]
      end

      # Contenu réel : la leçon Thalès au format 2, telle que l'équipe l'importe.
      test "the Thalès lesson in format 2 imports 1 lesson, 4 notions and 8 exercises" do
        file = Rails.root.join("docs/contenus/lecons-traitees/3eme/mathematiques/proprietes-de-thales-dans-un-triangle.json")

        report = run_import(JSON.parse(file.read))

        assert_equal [ "completed", 1, 0, 0 ], report.values_at(:status, :imported_count, :error_count, :skipped_count)
        assert_equal 4, report.details["essentials_created"]
        assert_equal 8, report.details["exercises_created"]
        lesson = Orm::Course.find_by!(slug: "proprietes-de-thales-dans-un-triangle")
        assert_equal [ 4, 4 ], [ exercises_of(lesson).where.not(essential_id: nil).count, exercises_of(lesson).where(essential_id: nil).count ]
        assert_equal [ "fixation" ], exercises_of(lesson).where.not(essential_id: nil).distinct.pluck(:exercise_type)
        assert_equal [ "evaluation" ], exercises_of(lesson).where(essential_id: nil).distinct.pluck(:exercise_type)
        assert_equal 0, exercises_of(lesson).where(statement: [ nil, "" ]).count
      end

      def schema_pairs(report) = report.import_errors.map { it.values_at("path", "code") }

      def close_session(session)
        sessions = Repositories::Assessment::ExerciseSessionRepository.new
        entity = sessions.find_by_public_id(public_id: session.public_id)
        UseCases::Assessment::CloseExerciseSession.new(
          sessions:, badges: Repositories::Assessment::BadgeRepository.new, gaps: Repositories::Assessment::KnowledgeGapRepository.new,
          policy: Policies::Assessment::SubmitAttemptPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
        ).call(actor: Entities::Identity::Actor.new(user_id: session.student_id, role: :student), session: entity,
               essential_id: session.exercise.essential_id).value
      end

      # Menace M2 : un fichier imbriqué à 102 niveaux est illisible, rien n'est écrit.
      test "a file nested 102 levels deep is rejected as unreadable, with zero writes" do
        report = run_import(("[" * 102) + ("]" * 102))

        assert_equal "rejected", report.status
        assert_equal [ [ "$", "json_invalid" ] ], schema_pairs(report)
        assert_equal [ 0, 0, 0, 0, 0 ], tree_counts
      end

      # Menace M4 : 501 leçons dans l'envoi, refus en bloc.
      test "501 lessons in one file are rejected in bloc, with zero writes" do
        report = run_import(document(*Array.new(501) { course("Cours") }))

        assert_equal "rejected", report.status
        assert_equal [ [ "courses", "too_many_roots" ] ], schema_pairs(report)
        assert_equal [ 0, 0, 0, 0, 0 ], tree_counts
      end

      # Menace M6, M7 (décision de l'orchestrateur, Q1 et Q2) : plafonds du schéma, au chiffre près.
      test "50 notions in a lesson are imported, 51 are refused by the schema before any write" do
        essential = course["essentials"].first
        build = ->(count) { course("Plafond", essentials: Array.new(count) { |index| essential.merge("name" => "Notion #{index + 1}") }) }

        report = run_import(document(build.call(51)))
        assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count)
        assert_equal [ [ "courses[0].essentials", "schema" ] ], schema_pairs(report)
        assert_equal 0, Orm::Course.count

        report = run_import(document(build.call(50)))
        assert_equal [ 1, 0 ], report.values_at(:imported_count, :error_count)
        assert_equal 50, Orm::Essential.count
      end

      test "30 questions in an exercise are imported, 31 are refused by the schema" do
        build = lambda do |count|
          broken = course("Plafond")
          broken["exercises"][0]["questions"] = Array.new(count) { |index| broken["exercises"][0]["questions"].first.merge("content" => "Q#{index}") }
          broken
        end

        report = run_import(document(build.call(31)))
        assert_equal [ [ "courses[0].exercises[0].questions", "schema" ] ], schema_pairs(report)
        assert_equal 0, Orm::Course.count

        assert_equal [ 1, 0 ], run_import(document(build.call(30))).values_at(:imported_count, :error_count)
        assert_equal 30, Orm::Question.where(exercise_id: Orm::Exercise.where(title: "Bilan 1")).count
      end

      test "10 answers to a question are imported, 11 are refused by the schema" do
        build = lambda do |count|
          broken = course("Plafond")
          broken["exercises"][0]["questions"] = [ { "content" => "Choisis.", "question_type" => "single_choice",
                                                    "answers" => Array.new(count) { |index| { "content" => "R#{index}", "correct" => index.zero? } } } ]
          broken
        end

        report = run_import(document(build.call(11)))
        assert_equal [ [ "courses[0].exercises[0].questions[0].answers", "schema" ] ], schema_pairs(report)

        assert_equal [ 1, 0 ], run_import(document(build.call(10))).values_at(:imported_count, :error_count)
        assert_equal 10, Orm::Answer.joins(:question).where(questions: { content: "Choisis." }).count
      end

      test "a subject of 5,000 characters is imported, 5,001 is refused at its path, notion or lesson-wide" do
        limit = Entities::Assessment::Exercise::STATEMENT_MAX
        over_lesson = course("Dépassé 1")
        over_lesson["exercises"][1]["statement"] = "a" * (limit + 1)
        over_notion = course("Dépassé 2")
        over_notion["essentials"][0]["exercises"][0]["statement"] = "a" * (limit + 1)
        exact = course("Exact")
        exact["exercises"][1]["statement"] = "a" * limit

        report = run_import(document(over_lesson, over_notion, exact))

        assert_equal 5_000, limit
        assert_equal [ 3, 1, 2 ], report.values_at(:total_count, :imported_count, :error_count)
        assert_equal [ [ "courses[0].exercises[1].statement", "schema" ], [ "courses[1].essentials[0].exercises[0].statement", "schema" ] ],
                     schema_pairs(report).sort
        assert_equal limit, Orm::Exercise.find_by!(title: "Bilan 2").statement.length
      end

      # Revue sécurité du Lot C (#334) : à deux éléments, le mélange montrerait toujours l'inverse de la solution.
      test "an ordering question needs 3 steps at least: 2 refused at their path, 3 accepted" do
        build = lambda do |count|
          broken = course("Ordre")
          broken["exercises"][0]["questions"] = [ { "content" => "Range.", "question_type" => "ordering",
                                                    "answers" => Array.new(count) { |index| { "content" => "Étape #{index + 1}" } } } ]
          broken
        end

        report = run_import(document(build.call(2)))
        assert_equal [ [ "courses[0].exercises[0].questions[0].answers", "question_structure" ] ], schema_pairs(report)
        assert_equal({ "rule" => "steps_count" }, report.import_errors.first["params"])

        assert_equal [ 1, 0 ], run_import(document(build.call(3))).values_at(:imported_count, :error_count)
      end

      test "a matching question needs 3 pairs at least: 2 refused at their path, 3 accepted" do
        build = lambda do |count|
          broken = course("Relier")
          broken["exercises"][0]["questions"] = [ { "content" => "Relie.", "question_type" => "matching",
                                                    "answers" => Array.new(count) { |index| { "content" => "G#{index}", "match" => "D#{index}" } } } ]
          broken
        end

        report = run_import(document(build.call(2)))
        assert_equal [ [ "courses[0].exercises[0].questions[0].answers", "question_structure" ] ], schema_pairs(report)
        assert_equal({ "rule" => "pairs_count" }, report.import_errors.first["params"])

        assert_equal [ 1, 0 ], run_import(document(build.call(3))).values_at(:imported_count, :error_count)
      end

      # Réimport (décision du porteur) : la leçon et ses notions restent, les exercices sont archivés, les nouveaux arrivent en brouillon.
      def existing_lesson(name: "Cours 1", notions: [ "Fiche 1", "Fiche 2" ])
        lesson = create_course(name:, level: Orm::Level.find_by!(slug: "tle"), material: Orm::Material.find_by!(slug: "svt"),
                               series: Orm::Series.find_by!(slug: "d"))
        notions.each { |notion| create_essential(course: lesson, name: notion) }
        lesson
      end

      test "reimporting an existing lesson archives its exercises, keeps a session in progress and writes the new drafts" do
        lesson = existing_lesson
        first, second = lesson.essentials.order(:position).to_a
        old = create_exercise(essential: first, questions: 3)
        old_wide = create_lesson_wide_exercise(course: lesson)
        old_draft = create_exercise(essential: second, status: "draft")
        session = create_exercise_session(student: create_student, exercise: old)
        assignment = create_assignment(assignable: old)
        old_questions = old.questions.order(:id).map { [ it.id, it.content, it.answers.order(:id).pluck(:id, :content, :correct) ] }
        lesson_before = lesson.reload.attributes
        essentials_before = lesson.essentials.order(:id).map(&:attributes)

        report = run_import(course_tree_v2_document(courses: 1, essentials: 2))

        assert_equal [ "completed", 1, 0, 0 ], report.values_at(:status, :imported_count, :error_count, :skipped_count)
        assert_equal 3, report.details["exercises_archived"]
        assert_equal 6, report.details["exercises_created"]
        assert_equal 0, report.details["essentials_created"]
        assert_equal [ 1, 2 ], [ Orm::Course.count, Orm::Essential.count ]
        assert_equal lesson_before, lesson.reload.attributes
        assert_equal essentials_before, lesson.essentials.order(:id).map(&:attributes)
        assert_equal [ [ "archived" ] * 3 ], [ Orm::Exercise.where(id: [ old, old_wide, old_draft ].map(&:id)).pluck(:status) ]
        assert_not_nil old.reload.archived_at
        assert_equal "archived", assignment.reload.status
        assert_not_nil assignment.archived_at
        assert_equal old_questions, old.questions.order(:id).map { [ it.id, it.content, it.answers.order(:id).pluck(:id, :content, :correct) ] }
        fresh = exercises_of(lesson).where(status: "draft")
        assert_equal 6, fresh.count
        assert_equal [ @author.id ], fresh.pluck(:author_id).uniq

        # La séance en cours garde ses questions : sa note se calcule sur question_count, figé au démarrage.
        assert_equal [ "started", 3 ], session.reload.values_at(:status, :question_count)
        create_attempt(session:, question: old.questions.order(:position).first)
        row = close_session(session)
        assert_equal "completed", session.reload.status
        assert_equal 33, row.score_percent
        assert_operator session.correct_count, :<=, session.question_count
      end

      test "a lesson without exercise is reimported too: nothing archived, the exercises created" do
        lesson = existing_lesson

        report = run_import(course_tree_v2_document(courses: 1, essentials: 2))

        assert_equal [ 6, nil ], [ report.details["exercises_created"], report.details["exercises_archived"] ]
        assert_equal 6, exercises_of(lesson).count
      end

      test "a second reimport archives the exercises of the first one" do
        lesson = existing_lesson

        run_import(course_tree_v2_document(courses: 1, essentials: 2))
        report = run_import(course_tree_v2_document(courses: 1, essentials: 2))

        assert_equal [ 6, 6 ], [ report.details["exercises_archived"], report.details["exercises_created"] ]
        assert_equal [ 6, 6 ], [ exercises_of(lesson).where(status: "archived").count, exercises_of(lesson).where(status: "draft").count ]
      end

      test "a reimport with a notion absent from the lesson refuses it, the notion named, and archives nothing" do
        lesson = existing_lesson(notions: [ "Fiche 1" ])
        old = create_exercise(essential: lesson.essentials.first)

        report = run_import(course_tree_v2_document(courses: 1, essentials: 2))

        assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count)
        assert_equal [ { "path" => "courses[0].essentials[1].name", "code" => "essential_not_in_lesson",
                         "params" => { "course" => "Cours 1", "name" => "Fiche 2" } } ], report.import_errors
        assert_equal "published", old.reload.status
        assert_equal 1, exercises_of(lesson).count
      end

      test "a version 1 file of an existing lesson is still skipped as a duplicate, exercises untouched" do
        lesson = existing_lesson
        old = create_exercise(essential: lesson.essentials.first)

        report = run_import(document(v1_course("Cours 1"), version: 1))

        assert_equal [ 0, 1, 0 ], report.values_at(:imported_count, :skipped_count, :error_count)
        assert_equal "published", old.reload.status
      end

      # Reprise de la revue du Lot 0 : l'ordre est celui du fichier, sans trou ni doublon, après les positions déjà prises.
      test "positions follow the file order, notions first then the 4 lesson-wide, after the ones already taken" do
        lesson = existing_lesson
        first, second = lesson.essentials.order(:position).to_a
        create_exercise(essential: first, position: 1)
        create_exercise(essential: second, position: 2)
        document = course_tree_v2_document(courses: 1, essentials: 2)
        document["courses"][0]["essentials"].reverse!

        run_import(document)

        fresh = exercises_of(lesson).where(status: "draft").order(:position)
        assert_equal (3..8).to_a, fresh.pluck(:position)
        assert_equal [ second.id, first.id, nil, nil, nil, nil ], fresh.pluck(:essential_id)
        assert_equal [ "Bilan 1", "Bilan 2", "Bilan 3", "Bilan 4" ], fresh.last(4).map(&:title)
        assert_equal (1..8).to_a, exercises_of(lesson).order(:position).pluck(:position)
      end

      # Reprise de la revue du Lot 0, M14 : l'import ne passe pas par le dépôt des exercices, donc n'atteint jamais
      # EssentialOutsideCourse ; il ne rattache que les notions de la leçon réimportée, trouvées par leur nom.
      test "a notion of another lesson is never reached: its name is unknown in the reimported lesson" do
        existing_lesson
        other = existing_lesson(name: "Autre leçon", notions: [ "Fiche 3" ])
        old = create_exercise(essential: other.essentials.first)
        document = course_tree_v2_document(courses: 1, essentials: 1)
        document["courses"][0]["essentials"][0]["name"] = "Fiche 3"

        report = run_import(document)

        assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count)
        assert_equal [ [ "courses[0].essentials[0].name", "essential_not_in_lesson" ] ], schema_pairs(report)
        assert_equal [ "published", 1 ], [ old.reload.status, exercises_of(other).count ]
      end

      # Revue sécurité du Lot D : 2.0 == 2 en Ruby, le validateur cherchait alors un schéma « v2.0 » inexistant.
      test "a version 2.0 envelope is rejected as version_unsupported, with zero writes" do
        [ 2.0, 1.0 ].each do |version|
          report = run_import(course_tree_v2_document(courses: 1).merge("version" => version))

          assert_equal "rejected", report.status
          assert_equal [ [ "version", "version_unsupported" ] ], schema_pairs(report)
        end
        assert_equal [ 0, 0, 0, 0, 0 ], tree_counts
      end

      # ADR-0113 (1 exercice par notion) : un réimport ne laisse jamais une notion de la leçon sans exercice.
      test "a reimport whose file lacks a notion of the lesson refuses the lesson and keeps the old exercise" do
        lesson = existing_lesson
        old_first = create_exercise(essential: lesson.essentials.order(:position).first)
        old_second = create_exercise(essential: lesson.essentials.order(:position).last)

        report = run_import(course_tree_v2_document(courses: 1, essentials: 1))

        assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count)
        assert_equal [ { "path" => "courses[0]", "code" => "essential_missing_from_file",
                         "params" => { "course" => "Cours 1", "name" => "Fiche 2" } } ], report.import_errors
        assert_equal [ "published", "published" ], [ old_first.reload.status, old_second.reload.status ]
        assert_equal 2, exercises_of(lesson).count
      end

      test "two notions of a lesson whose names differ by case or accents refuse the reimport, the name given" do
        lesson = existing_lesson(notions: [ "Génétique", "GENETIQUE" ])
        old = create_exercise(essential: lesson.essentials.first)
        document = course_tree_v2_document(courses: 1, essentials: 1)
        document["courses"][0]["essentials"][0]["name"] = "Génétique"

        report = run_import(document)

        assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count)
        assert_equal [ [ "courses[0]", "essential_name_ambiguous" ] ], schema_pairs(report)
        assert_equal "Génétique", report.import_errors.first.dig("params", "name")
        assert_equal "published", old.reload.status
        assert_equal 1, exercises_of(lesson).count
      end

      test "a reimport archives only the exercises of its own lesson: another lesson keeps its published exercise and active assignment" do
        existing_lesson
        other = existing_lesson(name: "Autre leçon", notions: [ "Fiche 1" ])
        other_exercise = create_exercise(essential: other.essentials.first)
        other_assignment = create_assignment(assignable: other_exercise)

        report = run_import(course_tree_v2_document(courses: 1, essentials: 2))

        assert_equal [ "completed", 1 ], report.values_at(:status, :imported_count)
        assert_equal "published", other_exercise.reload.status
        assert_nil other_exercise.archived_at
        assert_equal [ "active", nil ], [ other_assignment.reload.status, other_assignment.archived_at ]
      end

      test "an assignment already archived keeps its archived_at at reimport" do
        lesson = existing_lesson
        old = create_exercise(essential: lesson.essentials.first)
        assignment = create_assignment(assignable: old, status: "archived")
        before = assignment.reload.archived_at

        run_import(course_tree_v2_document(courses: 1, essentials: 2))

        assert_equal "archived", old.reload.status
        assert_equal before, assignment.reload.archived_at
      end

      test "a v2 reimport finds the lesson whatever the case, accents and spaces of its name" do
        lesson = existing_lesson(name: "Génétique et Évolution", notions: [ "Fiche 1", "Fiche 2" ])
        document = course_tree_v2_document(courses: 1, essentials: 2)
        document["courses"][0]["name"] = "  GENETIQUE   et  evolution "

        report = run_import(document)

        assert_equal [ "completed", 1, 0, 0 ], report.values_at(:status, :imported_count, :skipped_count, :error_count)
        assert_equal [ 1, 6 ], [ Orm::Course.count, exercises_of(lesson).count ]
      end

      test "the same lesson twice in one v2 envoi is written once" do
        lesson = existing_lesson
        one = course_tree_v2_document(courses: 1, essentials: 2)["courses"].first

        report = run_import(document(one, one))

        assert_equal [ "completed", 1, 1, 0 ], report.values_at(:status, :imported_count, :skipped_count, :error_count)
        assert_equal 6, exercises_of(lesson).count
        assert_equal 6, report.details["exercises_created"]
      end

      # Couverture reprise d'import_exercises_test.rb (retiré avec l'import d'exercices seuls, ADR-0113 §4.4), au format 2.
      def question_in_notion(question)
        root = course("Génétique")
        root["essentials"][0]["exercises"][0]["questions"] = [ question ]
        root
      end

      def numeric_question(**extra)
        { "content" => "Combien ?", "question_type" => "numeric", "answers" => [ { "content" => "3,5" } ], **extra.transform_keys(&:to_s) }
      end

      QUESTIONS_PATH = "courses[0].essentials[0].exercises[0].questions[0]".freeze

      test "a numeric tolerance too large (schema) or too precise (domain rule) is refused at .tolerance" do
        { 1e30 => "schema", 0.00001 => "question_structure" }.each do |tolerance, code|
          report = run_import(document(question_in_notion(numeric_question(tolerance:))))

          assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count), tolerance
          assert_equal [ [ "#{QUESTIONS_PATH}.tolerance", code ] ], schema_pairs(report), tolerance
        end
        assert_equal 0, Orm::Course.count
      end

      test "a negative tolerance is refused by the schema, at its path" do
        report = run_import(document(question_in_notion(numeric_question(tolerance: -1))))

        assert_equal [ [ "#{QUESTIONS_PATH}.tolerance", "schema" ] ], schema_pairs(report)
        assert_equal 0, Orm::Course.count
      end

      test "a fill-in-the-blank question without a blank is refused at .content with its rule" do
        question = { "content" => "Sans blanc.", "question_type" => "fill_blank", "answers" => [ { "content" => "Abidjan" } ] }

        report = run_import(document(question_in_notion(question)))

        assert_equal [ [ "#{QUESTIONS_PATH}.content", "blank_marker" ] ], report.import_errors.map { [ it["path"], it.dig("params", "rule") ] }
        assert_equal 0, Orm::Course.count
      end

      test "a tolerance on a question that is not numeric is refused with tolerance_not_allowed" do
        question = { "content" => "Choisis.", "question_type" => "single_choice", "tolerance" => 0.5,
                     "answers" => [ { "content" => "A", "correct" => true }, { "content" => "B" } ] }

        report = run_import(document(question_in_notion(question)))

        assert_equal [ [ "#{QUESTIONS_PATH}.tolerance", "tolerance_not_allowed" ] ], report.import_errors.map { [ it["path"], it.dig("params", "rule") ] }
        assert_equal 0, Orm::Course.count
      end

      test "a match longer than 500 characters is refused by the v2 schema, at its path" do
        answers = %w[a b c].map { { "content" => it, "match" => it.upcase } }
        answers[0]["match"] = "a" * 501

        report = run_import(document(question_in_notion({ "content" => "Relie.", "question_type" => "matching", "answers" => answers })))

        assert_equal [ [ "#{QUESTIONS_PATH}.answers[0].match", "schema" ] ], schema_pairs(report)
        assert_equal 0, Orm::Course.count
      end

      test "an author who lost the team role is refused: the import fails, nothing is written" do
        report = run_import(document(course), author: create_teacher)

        assert_equal :forbidden, @result.code
        assert_equal "failed", report.status
        assert_equal [ 0, 0, 0, 0, 0 ], tree_counts
      end
    end
  end
end
