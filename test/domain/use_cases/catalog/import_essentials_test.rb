require "test_helper"

# CA-15, ADR-0039: the essentials adapter on the real engine and repositories. An essential arrives in its target course,
# after the existing ones, with all its exercises, in draft, or not at all.
module UseCases
  module Catalog
    class ImportEssentialsTest < ActiveSupport::TestCase
      # The base refuses every batch holding the essential named `fragile` (a name taken between validation and write).
      class FragileWriter < Repositories::Catalog::ContentTreeWriter
        def initialize(fragile:)
          super()
          @fragile = fragile
        end

        def write(essentials: [], **)
          raise ActiveRecord::RecordNotUnique, "refus simulé" if essentials.any? { it.name == @fragile }

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
        @course = create_course(name: "Génétique et Évolution", status: "draft")
      end

      def adapter(writer: Repositories::Catalog::ContentTreeWriter.new)
        ImportEssentials.new(courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
                             writer:)
      end

      # The real engine, on a report in base and its file.
      def run_import(document, adapter: self.adapter, transaction: Repositories::Shared::Transaction.new, author: @author)
        report = create_import_report(kind: "essentials", imported_by: author)
        Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(document.to_json), filename: "fiches.json") ])
        @result = UseCases::Catalog::RunImport.new(
          adapter:, reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
          schema: Repositories::Catalog::ImportSchemaValidator.new, users: Repositories::Identity::UserRepository.new,
          audit_log: Repositories::Identity::AuditLogRepository.new, transaction:, clock: Time.zone
        ).call(report_id: report.id)
        report.reload
      end

      def document(*essentials, course: @course.slug) = { "format" => "lnclass.essentials", "version" => 1, "course" => course, "essentials" => essentials }

      def essential(name = "Brassage génétique", **overrides)
        essentials_document(course: @course.slug, essentials: 1, exercises: 2, questions: 2, answers: 3)
          .fetch("essentials").first.merge("name" => name, **overrides.transform_keys(&:to_s))
      end

      def context
        @context ||= adapter.prepare(target: adapter.resolve_target(document: document).value)
      end

      def validate(root, path: "essentials[0]") = adapter.validate_root(root:, path:, context:)

      def error_pairs(item) = item.errors.map { [ it.path, it.code ] }

      def tree_counts
        [ Orm::Essential, Orm::Exercise, Orm::Question, Orm::Answer ].map(&:count)
      end

      def positions(course = @course) = course.essentials.order(:position).pluck(:name, :position)

      test "honours the importer contract, and validate_root writes nothing" do
        assert_importer_contract ImportEssentials, adapter:, root: essential, context: context
        assert_equal ImportEssentials::POLICY, Entities::Catalog::ImportKind.fetch(ImportEssentials::KIND).policy
        assert_equal Policies::Catalog::ManageContentPolicy, ImportEssentials::POLICY
      end

      test "the target is the course of the envelope, by its exact slug, whatever its status" do
        result = adapter.resolve_target(document: document(course: " #{@course.slug} "))

        assert result.success?
        assert_equal [ @course.id, "Génétique et Évolution" ], [ result.value.id, result.value.name ]
        assert_equal :not_found, adapter.resolve_target(document: document(course: "Génétique et Évolution")).code
        assert_equal :not_found, adapter.resolve_target(document: document(course: "inconnu")).code
      end

      test "a valid essential is planned in the target course with its exercises, and keyed by course and normalized name" do
        item = validate(essential("  Brassage   génétique ", subtitle: " Méiose ", content: "<p>Texte</p>"))

        assert item.valid?
        node = item.plan
        assert_equal [ "genetique-et-evolution-brassage-genetique", @course.id, "Brassage génétique", "Méiose", "<p>Texte</p>" ],
                     [ node.slug, node.course_id, node.name, node.subtitle, node.content ]
        assert_equal [ @course.id, "brassage genetique" ], item.key
        assert_equal [ [ 1, 14, "Exercice 1", "Consigne 1" ], [ 2, 14, "Exercice 2", "Consigne 2" ] ],
                     node.exercises.map { [ it.position, it.public_id.length, it.title, it.description ] }
        assert_not_equal(*node.exercises.map(&:public_id))
        assert_equal [ [ 1, "Question 1", nil ], [ 2, "Question 2", nil ] ],
                     node.exercises.first.questions.map { [ it.position, it.content, it.explanation ] }
        assert_equal [ [ 1, true ], [ 2, false ], [ 3, false ] ], node.exercises.first.questions.first.answers.map { [ it.position, it.correct ] }
      end

      test "an essential without exercise is valid, and the old application keys of an exercise are read" do
        bare = validate(essential("Mutation", subtitle: nil, exercises: []))
        assert_equal [ true, nil, [] ], [ bare.valid?, bare.plan.subtitle, bare.plan.exercises ]

        root = essential("Sélection", status: "publié")
        exercise = root["exercises"][0]
        exercise["name"] = exercise.delete("title")
        exercise["questions"][0]["answers"] = [ { "content" => "Oui", "is_correct" => true }, { "content" => "Non" },
                                                { "content" => "Peut-être", "is_correct" => false } ]
        exercise["questions"][1]["explanation"] = "  Parce que.  "

        planned = validate(root).plan.exercises.first
        assert_equal "Exercice 1", planned.title
        assert_equal [ true, false, false ], planned.questions.first.answers.map(&:correct)
        assert_equal [ nil, "Parce que." ], planned.questions.map(&:explanation)
      end

      test "a name without latin letter still gets a slug, and a slug taken in base or in the file gets a suffix" do
        create_essential(course: @course, name: "Méiose")
        first = validate(essential("Méiose ?"), path: "essentials[0]").plan
        second = validate(essential("Méiose !"), path: "essentials[1]").plan
        greek = validate(essential("∑"), path: "essentials[2]").plan

        assert_equal [ "genetique-et-evolution-meiose-2", "genetique-et-evolution-meiose-3", "genetique-et-evolution" ],
                     [ first.slug, second.slug, greek.slug ]

        @course = create_course(name: "π")
        @context = nil
        assert_equal "essential", validate(essential("∑")).plan.slug
      end

      test "an error deep in the essential is reported at its exact path, with no plan" do
        root = essential
        root["exercises"][1]["questions"][0]["answers"].each { it["correct"] = true }
        root["exercises"][0]["exercise_type"] = "quiz"

        item = validate(root, path: "essentials[4]")

        assert_equal [ [ "essentials[4].exercises[0].exercise_type", "invalid_value" ],
                       [ "essentials[4].exercises[1].questions[0].answers", "question_structure" ] ], error_pairs(item)
        assert_nil item.plan
      end

      test "a mixed file gives an exact report: after the existing essentials, in draft, invalid ones leave no row" do
        create_essential(course: @course, name: "Introduction")
        create_essential(course: @course, name: "Fiche 9")
        mixed = mixed(essentials_document(course: @course.slug, essentials: 10, exercises: 2, questions: 3, answers: 4),
                      invalid_at: [ 4 ], duplicate_of: { 6 => 2 })
        mixed["essentials"][1]["exercises"][1]["questions"][2]["answers"].first(2).each { it["correct"] = true }
        mixed["essentials"][8]["name"] = "  FICHE   9 "

        report = run_import(mixed)

        assert_equal [ "completed", 10, 6, 2, 2 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ [ "essentials[1].exercises[1].questions[2].answers", "question_structure" ], [ "essentials[4].name", "blank" ] ],
                     report.import_errors.map { it.values_at("path", "code") }
        assert_equal [ [ "Introduction", 1 ], [ "Fiche 9", 2 ], [ "Fiche 1", 3 ], [ "Fiche 3", 4 ], [ "Fiche 4", 5 ], [ "Fiche 6", 6 ],
                       [ "Fiche 8", 7 ], [ "Fiche 10", 8 ] ], positions
        assert_equal({ "exercises_created" => 12, "questions_created" => 36, "answers_created" => 144 }, report.details)
        assert_equal [ 8, 12, 36, 144 ], tree_counts
        [ Orm::Exercise, Orm::Essential.where.not(name: [ "Introduction", "Fiche 9" ]) ].each do |scope|
          assert_equal [ [ "draft", @author.id, nil ] ], scope.distinct.pluck(:status, :author_id, :published_at)
        end
        assert_equal "<p>Fiche 1</p>", Orm::Essential.find_by!(name: "Fiche 1").content.body.to_html
      end

      test "an essential never lands in another course than the target, and a same name elsewhere is no duplicate" do
        other = create_course(name: "Écologie")
        create_essential(course: other, name: "Brassage génétique")
        before = positions(other)

        report = run_import(document(essential, essential("Mutation")))

        assert_equal [ 2, 2, 0 ], report.values_at(:total_count, :imported_count, :skipped_count)
        assert_equal [ [ "Brassage génétique", 1 ], [ "Mutation", 2 ] ], positions
        assert_equal before, positions(other)
        assert_equal [ @course.id ], Orm::Essential.where(author_id: @author.id).distinct.pluck(:course_id)
      end

      test "an unknown course slug is rejected in bloc, with zero writes; a missing one is refused by the schema" do
        report = run_import(essentials_document(course: "cours-inconnu", essentials: 3))

        assert_equal [ "rejected", 0 ], report.values_at(:status, :total_count)
        assert_equal [ { "path" => "course", "code" => "unknown_target", "params" => { "value" => "cours-inconnu" } } ], report.import_errors

        missing = run_import(essentials_document(course: nil, essentials: 1).except("course"))
        assert_equal [ [ "course", "schema" ] ], missing.import_errors.map { it.values_at("path", "code") }
        assert_equal [ 0, 0, 0, 0 ], tree_counts
      end

      test "a batch refused by the base is replayed essential by essential, and positions stay without gap" do
        transaction = CountingTransaction.new

        report = run_import(document(essential("Solide"), essential("Fragile"), essential("Robuste")),
                            adapter: adapter(writer: FragileWriter.new(fragile: "Fragile")), transaction:)

        assert_equal [ "completed", 3, 2, 1 ], report.values_at(:status, :total_count, :imported_count, :error_count)
        assert_equal [ { "path" => "essentials[1]", "code" => "write_failed", "params" => {} } ], report.import_errors
        assert_equal 1 + 3, transaction.attempts
        assert_equal [ [ "Solide", 1 ], [ "Robuste", 2 ] ], positions
        assert_equal [ 2, 4, 8, 24 ], tree_counts
        assert_equal 4, report.details["exercises_created"]
      end

      test "an author who lost the team role is refused: the import fails, nothing is written" do
        report = run_import(document(essential), author: create_teacher)

        assert_equal :forbidden, @result.code
        assert_equal "failed", report.status
        assert_equal [ 0, 0, 0, 0 ], tree_counts
      end
    end
  end
end
