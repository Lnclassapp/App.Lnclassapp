require "test_helper"

# ADR-XXXX entraînement de notion corrigé sans trace et questions à plusieurs cases : le schéma v3 porte `notions[].practice`,
# `question.hint` et `answer.blank`, et l'import les valide puis les écrit (sur le vrai moteur et les vrais dépôts).
module UseCases
  module Catalog
    class ImportCourseTreePracticeTest < ActiveSupport::TestCase
      setup do
        seed_referential
        @author = create_team_member(team_role: "content", second_factor: false)
      end

      def adapter
        ImportCourseTree.new(courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
                             taxonomy: Repositories::Catalog::TaxonomyRepository.new, writer: Repositories::Catalog::ContentTreeWriter.new)
      end

      def run_import(*courses)
        report = create_import_report(kind: "course_tree", imported_by: @author)
        files = courses.each_with_index.map do |course, index|
          import_upload(io: StringIO.new({ "format" => "lnclass.course-tree", "version" => 3, "courses" => [ course ] }.to_json), filename: "lecon-#{index}.json")
        end
        Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files:)
        UseCases::Catalog::RunImport.new(
          adapter:, reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
          schema: Repositories::Catalog::ImportSchemaValidator.new, users: Repositories::Identity::UserRepository.new,
          audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
        ).call(report_id: report.id)
        report.reload
      end

      def report_pairs(report) = report.import_errors.map { it.values_at("path", "code") }

      def practice
        { "statement" => "Les droites (MN) et (BC) sont parallèles.",
          "questions" => [ { "content" => "AN (cm) = ___", "question_type" => "numeric", "unit" => "cm", "tolerance" => 0.01,
                             "hint" => "Écris l'égalité des trois rapports.",
                             "explanation" => "AN = AC × AM / AB = 4,8 cm, par le théorème de Thalès.",
                             "answers" => [ { "content" => "4,8", "correct" => true, "blank" => 0 } ] } ] }
      end

      def lesson_with(practice_value)
        lesson = revision_sheet_document.fetch("courses").first
        lesson["notions"][0]["practice"] = practice_value
        question = lesson["notions"][0]["exercise"]["questions"][0]
        question["hint"] = "Pense à additionner."
        question["answers"].each { it["blank"] = 0 }
        lesson
      end

      test "a lesson with practice, hint and blank is imported and the database carries the values" do
        report = run_import(lesson_with(practice))

        assert_equal [ "completed", 1, 0 ], report.values_at(:status, :imported_count, :error_count), report_pairs(report).inspect
        first, second = Orm::Course.find_by!(slug: "racines-carrees").essentials.order(:position)
        assert_equal practice, first.sheet["practice"]
        refute second.sheet.key?("practice"), "une notion sans entraînement n'a pas de clé practice"
        question = first.exercises.first.questions.order(:position).first
        assert_equal "Pense à additionner.", question.hint
        assert_equal [ 0, 0 ], question.answers.pluck(:blank)
        assert_nil first.exercises.first.questions.order(:position).last.hint
      end

      test "the plan carries practice, hint and blank" do
        subject = adapter
        item = subject.validate_root(root: lesson_with(practice), path: "courses[0]", context: subject.prepare(target: nil))

        assert item.valid?, item.errors.inspect
        notion = item.plan.notions.first
        assert_equal practice, notion.sheet["practice"]
        assert_equal "Pense à additionner.", notion.exercises.first.questions.first.hint
        assert_equal [ 0, 0 ], notion.exercises.first.questions.first.answers.map(&:blank)
      end

      test "a practice with a forbidden key is refused whole, with the path of the key" do
        wrong = practice
        wrong["questions"][0]["points"] = 2

        report = run_import(lesson_with(wrong))

        assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count)
        assert_equal [ [ "courses[0].notions[0].practice.questions[0].points", "schema" ] ], report_pairs(report)
        assert_equal 0, Orm::Course.count
      end

      test "a practice with a broken question is refused by the adapter rules" do
        wrong = practice
        wrong["questions"][0]["explanation"] = "court"
        subject = adapter

        item = subject.validate_root(root: lesson_with(wrong), path: "courses[0]", context: subject.prepare(target: nil))

        assert_equal [ [ "courses[0].notions[0].practice.questions[0].explanation", "too_short" ] ], item.errors.map { [ it.path, it.code ] }
      end

      test "more than six practice questions are refused" do
        wrong = practice
        wrong["questions"] = Array.new(7) { practice["questions"].first }
        subject = adapter

        item = subject.validate_root(root: lesson_with(wrong), path: "courses[0]", context: subject.prepare(target: nil))

        assert_equal [ [ "courses[0].notions[0].practice.questions", "invalid_count" ] ], item.errors.map { [ it.path, it.code ] }
      end

      test "a blank above 5 on a graded answer is refused by the schema" do
        lesson = lesson_with(practice)
        lesson["notions"][0]["exercise"]["questions"][0]["answers"][0]["blank"] = 6

        report = run_import(lesson)

        assert_equal [ 0, 1 ], report.values_at(:imported_count, :error_count)
        assert_equal [ "courses[0].notions[0].exercise.questions[0].answers[0].blank" ], report_pairs(report).map(&:first)
      end

      test "a re-imported draft lesson gets the new practice" do
        run_import(lesson_with(practice))
        changed = practice
        changed["statement"] = "Autre énoncé."

        report = run_import(lesson_with(changed))

        assert_equal "completed", report.status, report_pairs(report).inspect
        assert_equal "Autre énoncé.", Orm::Course.find_by!(slug: "racines-carrees").essentials.order(:position).first.sheet.dig("practice", "statement")
      end
    end
  end
end
