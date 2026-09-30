require "test_helper"

# AS-06 replaced, TR-28, ADR-0039: the exercises adapter on the real engine and repositories. An exercise arrives in
# its target essential with its questions and answers, in draft, or not at all.
module UseCases
  module Assessment
    class ImportExercisesTest < ActiveSupport::TestCase
      # The base refuses every batch holding the exercise titled `fragile` (a position taken between validation and write).
      class FragileWriter < Repositories::Catalog::ContentTreeWriter
        def initialize(fragile:)
          super()
          @fragile = fragile
        end

        def write(exercises: [], **)
          raise ActiveRecord::RecordNotUnique, "refus simulé" if exercises.any? { it.title == @fragile }

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
        @author = create_team_member(team_role: "content", second_factor: false)
        @essential = create_essential(name: "Brassage génétique", status: "draft")
      end

      def adapter(writer: Repositories::Catalog::ContentTreeWriter.new)
        ImportExercises.new(essentials: Repositories::Catalog::EssentialRepository.new,
                            exercises: Repositories::Assessment::ExerciseRepository.new, writer:)
      end

      # The real engine, on a report in base and its file.
      def run_import(document, adapter: self.adapter, transaction: Repositories::Shared::Transaction.new, author: @author)
        report = create_import_report(kind: "exercises", imported_by: author)
        Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(document.to_json), filename: "exercices.json") ])
        @result = UseCases::Catalog::RunImport.new(
          adapter:, reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
          schema: Repositories::Catalog::ImportSchemaValidator.new, users: Repositories::Identity::UserRepository.new,
          audit_log: Repositories::Identity::AuditLogRepository.new, transaction:, clock: Time.zone
        ).call(report_id: report.id)
        report.reload
      end

      def document(*exercises, essential: @essential.slug)
        { "format" => "lnclass.exercises", "version" => 1, "essential" => essential, "exercises" => exercises }
      end

      def exercise(title = "Crossing-over", **overrides)
        exercises_document(essential: @essential.slug, exercises: 1, questions: 2, answers: 3)
          .fetch("exercises").first.merge("title" => title, **overrides.transform_keys(&:to_s))
      end

      def question(question_type, *correct)
        { "content" => "Énoncé", "question_type" => question_type,
          "answers" => correct.each_with_index.map { |value, index| { "content" => "Proposition #{index + 1}", "correct" => value } } }
      end

      def context
        subject = adapter
        [ subject, subject.prepare(target: subject.resolve_target(document: document).value) ]
      end

      def validate(root, path: "exercises[0]")
        subject, context = self.context
        subject.validate_root(root:, path:, context:)
      end

      def error_pairs(item) = item.errors.map { [ it.path, it.code, it.params ] }
      def tree_counts = [ Orm::Exercise, Orm::Question, Orm::Answer ].map(&:count)

      test "honours the importer contract, and validate_root writes nothing" do
        subject, context = self.context
        assert_importer_contract ImportExercises, adapter: subject, root: exercise, context: context
        assert_equal ImportExercises::POLICY, Entities::Catalog::ImportKind.fetch(ImportExercises::KIND).policy
        assert_equal Policies::Catalog::ManageContentPolicy, ImportExercises::POLICY
      end

      test "the target essential is found by its slug, whatever its status; unknown or missing, it is not found" do
        found = adapter.resolve_target(document: document(essential: " #{@essential.slug.upcase} "))

        assert found.success?
        assert_equal [ @essential.id, "Brassage génétique" ], [ found.value.id, found.value.name ]
        assert_equal :not_found, adapter.resolve_target(document: document(essential: "fiche-inconnue")).code
        assert_equal :not_found, adapter.resolve_target(document: document.except("essential")).code
      end

      test "a valid exercise is planned in its target: public id, question and answer positions, and its duplicate key" do
        item = validate(exercise("  Crossing   Over ", description: "  Lisez bien.  ", exercise_type: "evaluation"))

        assert item.valid?
        node = item.plan
        assert_equal [ 14, @essential.id, "Crossing Over", "Lisez bien.", "evaluation" ],
                     [ node.public_id.length, node.essential_id, node.title, node.description, node.exercise_type ]
        assert_equal [ [ 1, "Question 1", nil ], [ 2, "Question 2", nil ] ], node.questions.map { [ it.position, it.content, it.explanation ] }
        assert_equal [ [ 1, true ], [ 2, false ], [ 3, false ] ], node.questions.first.answers.map { [ it.position, it.correct ] }
        assert_equal [ @essential.id, "crossing over" ], item.key
        assert_not_equal node.public_id, validate(exercise).plan.public_id
      end

      test "the old application keys are read: an exercise name, is_correct; status is ignored" do
        root = exercise(nil, name: "Méiose", status: "publié", description: nil)
        root.delete("title")
        root["questions"][0]["answers"] = [ { "content" => " Oui ", "is_correct" => true }, { "content" => "Non" },
                                            { "content" => "Peut-être", "is_correct" => false } ]
        root["questions"][1]["explanation"] = "  Parce que.  "

        node = validate(root).plan

        assert_equal [ "Méiose", nil ], [ node.title, node.description ]
        assert_equal [ [ "Oui", true ], [ "Non", false ], [ "Peut-être", false ] ], node.questions.first.answers.map { [ it.content, it.correct ] }
        assert_equal [ nil, "Parce que." ], node.questions.map(&:explanation)
      end

      test "the four question types are accepted when well formed" do
        item = validate(exercise(questions: [ question("true_false", false, true), question("single_choice", false, true, false),
                                              question("multiple_correct_2", true, false, true),
                                              question("multiple_correct_3", true, true, false, true) ]))

        assert item.valid?
        assert_equal %w[true_false single_choice multiple_correct_2 multiple_correct_3], item.plan.questions.map(&:question_type)
        assert_equal [ 2, 3, 3, 4 ], item.plan.questions.map { it.answers.size }
      end

      test "each malformed question is reported at its path, with its rule" do
        item = validate(exercise(questions: [ question("true_false", true, false, false), question("single_choice", true, true, false),
                                              question("multiple_correct_2", true, true), question("multiple_correct_3", true, true, false, false),
                                              question("open", true), question("single_choice", true, false).merge("content" => " ") ]),
                        path: "exercises[4]")

        assert_equal [ [ "exercises[4].questions[0].answers", "question_structure", { rule: :true_false_needs_two_answers } ],
                       [ "exercises[4].questions[1].answers", "question_structure", { rule: :wrong_correct_count } ],
                       [ "exercises[4].questions[2].answers", "question_structure", { rule: :too_few_answers } ],
                       [ "exercises[4].questions[3].answers", "question_structure", { rule: :wrong_correct_count } ],
                       [ "exercises[4].questions[4].question_type", "invalid_value", { value: "open" } ],
                       [ "exercises[4].questions[5].content", "blank", {} ] ], error_pairs(item)
        assert_nil item.plan
      end

      test "an exercise without title, type or question is in error at each key" do
        item = validate(exercise(" ", exercise_type: "quiz", questions: []))

        assert_equal [ [ "exercises[0].title", "blank", {} ], [ "exercises[0].exercise_type", "invalid_value", { value: "quiz" } ],
                       [ "exercises[0].questions", "blank", {} ] ], error_pairs(item)
      end

      test "a true or false question with 3 answers is refused: its exercise leaves no row, the others are written" do
        broken = exercise("Vrai ou faux", questions: [ question("true_false", true, false, false) ])

        report = run_import(document(exercise("Méiose"), broken))

        assert_equal [ "completed", 2, 1, 0, 1 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ { "path" => "exercises[1].questions[0].answers", "code" => "question_structure",
                         "params" => { "rule" => "true_false_needs_two_answers" } } ], report.import_errors
        assert_equal [ "Méiose" ], Orm::Exercise.pluck(:title)
        assert_equal [ 1, 2, 6 ], tree_counts
      end

      test "exercises are written in draft in the target essential, after its exercises, by the importing author" do
        create_exercise(essential: @essential, title: "Déjà là", questions: 0)
        create_exercise(essential: create_essential, title: "Ailleurs", questions: 0)

        report = run_import(document(exercise("Méiose", status: "publié"), exercise("Mitose", status: "published")))

        assert_equal [ "completed", 2, 2, 0, 0 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal({ "questions_created" => 4, "answers_created" => 12 }, report.details)
        imported = Orm::Exercise.where(title: %w[Méiose Mitose]).order(:position)
        assert_equal [ [ "Méiose", 2 ], [ "Mitose", 3 ] ], imported.pluck(:title, :position)
        assert_equal [ [ @essential.id, "draft", @author.id, nil ] ],
                     Orm::Exercise.where(id: imported.ids).distinct.pluck(:essential_id, :status, :author_id, :published_at)
        assert_equal [ [ 1, "Question 1" ], [ 2, "Question 2" ] ], imported.first.questions.order(:position).pluck(:position, :content)
      end

      test "a mixed file gives an exact report, and invalid exercises leave no row at all" do
        create_exercise(essential: @essential, title: "EXERCICE  9", questions: 0)
        create_exercise(essential: create_essential, title: "Exercice 4", questions: 0)
        mixed = mixed(exercises_document(essential: @essential.slug, exercises: 10, questions: 3, answers: 4),
                      invalid_at: [ 6 ], duplicate_of: { 5 => 1 })
        mixed["exercises"][2]["questions"][1]["answers"].first(2).each { it["correct"] = true }

        report = run_import(mixed)

        assert_equal [ "completed", 10, 6, 2, 2 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ [ "exercises[2].questions[1].answers", "question_structure" ], [ "exercises[6].title", "blank" ] ],
                     report.import_errors.map { it.values_at("path", "code") }
        assert_equal [ "Exercice 1", "Exercice 2", "Exercice 4", "Exercice 5", "Exercice 8", "Exercice 10" ],
                     Orm::Exercise.where(essential_id: @essential.id, status: "draft").order(:position).pluck(:title)
        assert_equal [ 2, 3, 4, 5, 6, 7 ], Orm::Exercise.where(essential_id: @essential.id, status: "draft").order(:position).pluck(:position)
        assert_equal [ 8, 6 * 3, 6 * 12 ], tree_counts
        assert_equal({ "questions_created" => 18, "answers_created" => 72 }, report.details)
      end

      test "an unknown or missing essential rejects the file in bloc, with zero writes" do
        unknown = run_import(document(exercise, essential: "fiche-inconnue"))
        missing = run_import(document(exercise).except("essential"))

        assert_equal [ "rejected", 0 ], unknown.values_at(:status, :total_count)
        assert_equal [ { "path" => "essential", "code" => "unknown_target", "params" => { "value" => "fiche-inconnue" } } ],
                     unknown.import_errors
        assert_equal [ "rejected", [ [ "essential", "schema" ] ] ], [ missing.status, missing.import_errors.map { it.values_at("path", "code") } ]
        assert_equal [ 0, 0, 0 ], tree_counts
      end

      test "an answer longer than the column is refused by the schema, at its path" do
        long = exercise("Long")
        long["questions"][1]["answers"][2]["content"] = "a" * 501

        report = run_import(document(long, exercise("Court")))

        assert_equal [ 2, 1, 1 ], report.values_at(:total_count, :imported_count, :error_count)
        assert_equal [ [ "exercises[0].questions[1].answers[2].content", "schema" ] ], report.import_errors.map { it.values_at("path", "code") }
      end

      test "a batch refused by the base is replayed exercise by exercise, and only the refused one is in error" do
        transaction = CountingTransaction.new

        report = run_import(document(exercise("Solide"), exercise("Fragile"), exercise("Robuste")),
                            adapter: adapter(writer: FragileWriter.new(fragile: "Fragile")), transaction:)

        assert_equal [ "completed", 3, 2, 1 ], report.values_at(:status, :total_count, :imported_count, :error_count)
        assert_equal [ { "path" => "exercises[1]", "code" => "write_failed", "params" => {} } ], report.import_errors
        assert_equal 1 + 3, transaction.attempts
        assert_equal [ [ "Solide", 1 ], [ "Robuste", 2 ] ], Orm::Exercise.order(:position).pluck(:title, :position)
        assert_equal [ 2, 4, 12 ], tree_counts
      end

      test "an author who lost the team role is refused: the import fails, nothing is written" do
        report = run_import(document(exercise), author: create_teacher)

        assert_equal :forbidden, @result.code
        assert_equal "failed", report.status
        assert_equal [ 0, 0, 0 ], tree_counts
      end
    end
  end
end
