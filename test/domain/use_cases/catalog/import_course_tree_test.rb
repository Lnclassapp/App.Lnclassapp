require "test_helper"

# CA-08, ADR-0039: the course tree adapter on the real engine and repositories, with the development referential
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
      def run_import(document, adapter: self.adapter, transaction: Repositories::Shared::Transaction.new, author: @author)
        report = create_import_report(kind: "course_tree", imported_by: author)
        Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(document.to_json), filename: "cours.json") ])
        @result = UseCases::Catalog::RunImport.new(
          adapter:, reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
          schema: Repositories::Catalog::ImportSchemaValidator.new, users: Repositories::Identity::UserRepository.new,
          audit_log: Repositories::Identity::AuditLogRepository.new, transaction:, clock: Time.zone
        ).call(report_id: report.id)
        report.reload
      end

      def document(*courses) = { "format" => "lnclass.course-tree", "version" => 1, "courses" => courses }

      def course(name = "Génétique et Évolution", **overrides)
        course_tree_document(courses: 1, essentials: 1, exercises: 1, questions: 2, answers: 3)
          .fetch("courses").first.merge("name" => name, **overrides.transform_keys(&:to_s))
      end

      def validate(root)
        subject = adapter
        subject.validate_root(root:, path: "courses[0]", context: subject.prepare(target: nil))
      end

      def error_pairs(item) = item.errors.map { [ it.path, it.code ] }
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
        assert_equal [ 14, 1, "fixation", "Consigne 1" ], [ exercise.public_id.length, exercise.position, exercise.exercise_type, exercise.description ]
        assert_not_equal exercise.public_id, node.essentials.last.exercises.first.public_id
        assert_equal [ [ 1, "Question 1" ], [ 2, "Question 2" ] ], exercise.questions.map { [ it.position, it.content ] }
        assert_equal [ [ 1, true ], [ 2, false ], [ 3, false ] ], exercise.questions.first.answers.map { [ it.position, it.correct ] }
      end

      test "the old application keys are read: nom, sous_titre, an exercise name, is_correct; status is ignored" do
        root = course(nil, nom: "Optique", sous_titre: "Lumière", status: "publié", series_name: nil)
        root.delete("name")
        root.delete("subtitle")
        exercise = root["essentials"][0]["exercises"][0]
        exercise["name"] = exercise.delete("title")
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
        assert_equal({ "essentials_created" => 1, "exercises_created" => 1, "questions_created" => 2, "answers_created" => 6 },
                     report.details)
        assert_equal [ 2, 1, 1, 2, 6 ], tree_counts
        assert_equal "physique-chimie", Orm::Course.find_by!(name: "Génétique").material.slug
        [ Orm::Course, Orm::Essential, Orm::Exercise ].each do |model|
          assert_equal [ [ "draft", @author.id, nil ] ], model.distinct.pluck(:status, :author_id, :published_at), model
        end
        assert_equal "<p>Cours 1</p>", Orm::Course.find_by!(name: "Écologie").content.body.to_html
      end

      test "an error deep in the tree is reported at its exact path, and its course leaves no row" do
        courses = course_tree_document(courses: 4, essentials: 2, exercises: 1, questions: 3, answers: 4)["courses"]
        courses[3]["essentials"][1]["exercises"][0]["questions"][2]["answers"].each { it["correct"] = true }

        report = run_import(document(*courses))

        assert_equal [ "completed", 4, 3, 0, 1 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ { "path" => "courses[3].essentials[1].exercises[0].questions[2].answers", "code" => "question_structure",
                         "params" => { "rule" => "wrong_correct_count" } } ], report.import_errors
        assert_not Orm::Course.exists?(name: "Cours 4")
        assert_equal [ 3, 6, 6, 18, 72 ], tree_counts
      end

      test "duplicates in base and in the file are skipped and counted; the existing course is not modified" do
        existing = create_course(name: "Génétique et Évolution", level: Orm::Level.find_by!(slug: "tle"),
                                 material: Orm::Material.find_by!(slug: "svt"), series: Orm::Series.find_by!(slug: "d"))
        before = existing.reload.attributes

        report = run_import(document(course("GENETIQUE et evolution"), course("Génétique  etÉvolution", series_name: "C"),
                                     course("Écologie"), course("écologie ")))

        assert_equal [ 4, 2, 2, 0 ], report.values_at(:total_count, :imported_count, :skipped_count, :error_count)
        assert_equal before, existing.reload.attributes
        assert_equal 0, existing.essentials.count
        assert_equal [ "c" ], Orm::Course.where.not(id: existing.id).where("name ILIKE 'Génétique%'").map { it.series.slug }
      end

      test "a mixed file gives an exact report, and invalid courses leave no row at all" do
        existing = create_course(name: "Cours 8", level: Orm::Level.find_by!(slug: "tle"), material: Orm::Material.find_by!(slug: "svt"),
                                 series: Orm::Series.find_by!(slug: "d"))
        mixed = course_tree_document(courses: 10, essentials: 2, exercises: 3, questions: 4, answers: 3)
        mixed["courses"][1]["essentials"][0]["exercises"][2]["questions"][3]["answers"].first(2).each { it["correct"] = true }
        mixed["courses"][4]["material_name"] = "Astronomie"

        report = run_import(mixed)

        assert_equal [ "completed", 10, 7, 1, 2 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ [ "courses[1].essentials[0].exercises[2].questions[3].answers", "question_structure" ],
                       [ "courses[4].material_name", "unknown_material" ] ], report.import_errors.map { it.values_at("path", "code") }
        assert_equal [ "Cours 1", "Cours 3", "Cours 4", "Cours 6", "Cours 7", "Cours 8", "Cours 9", "Cours 10" ].sort,
                     Orm::Course.pluck(:name).sort
        assert_equal 0, existing.essentials.count
        assert_equal [ 8, 7 * 2, 7 * 6, 7 * 24, 7 * 72 ], tree_counts
        assert_equal({ "essentials_created" => 14, "exercises_created" => 42, "questions_created" => 168, "answers_created" => 504 },
                     report.details)
      end

      test "the mixed helper file: invalid names and in-file duplicates are counted, nothing invalid is written" do
        report = run_import(mixed(course_tree_document(courses: 9, essentials: 1, exercises: 1, questions: 1, answers: 2)))

        assert_equal [ "completed", 9, 6, 1, 2 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ [ "courses[3].name", "blank" ], [ "courses[7].name", "blank" ] ], report.import_errors.map { it.values_at("path", "code") }
        assert_equal [ 6, 6, 6, 6, 12 ], tree_counts
      end

      test "an answer longer than the column is refused by the schema, at its path" do
        long = course("Long")
        long["essentials"][0]["exercises"][0]["questions"][1]["answers"][2]["content"] = "a" * 501

        report = run_import(document(long, course("Court")))

        assert_equal [ 2, 1, 1 ], report.values_at(:total_count, :imported_count, :error_count)
        assert_equal [ [ "courses[0].essentials[0].exercises[0].questions[1].answers[2].content", "schema" ] ],
                     report.import_errors.map { it.values_at("path", "code") }
      end

      test "a version 2 envelope is rejected in bloc, with zero writes" do
        report = run_import(course_tree_document(courses: 3).merge("version" => 2))

        assert_equal "rejected", report.status
        assert_equal [ [ "version", "version_unsupported" ] ], report.import_errors.map { it.values_at("path", "code") }
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
        assert_equal [ 2, 2, 2, 4, 12 ], tree_counts
        assert_equal 4, report.details["questions_created"]
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
