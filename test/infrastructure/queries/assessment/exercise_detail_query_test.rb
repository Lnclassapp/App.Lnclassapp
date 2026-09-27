require "test_helper"

# AS-02, AS-39 (plan boucle-pedagogique, Lot C1) : le détail d'un exercice. Sans reveal, la query ne lit même pas la colonne
# answers.correct, ni l'explication : la vue d'un élève ne peut rien fuiter, même par erreur (sécurité n° 29).
module Queries
  module Assessment
    class ExerciseDetailQueryTest < ActiveSupport::TestCase
      setup do
        course = create_course(name: "Génétique et évolution", level: create_level(name: "Tle"), series: create_series(name: "D"),
                               material: create_material(name: "SVT", category: "science"))
        @essential = create_essential(course:, name: "La méiose")
        @exercise = create_exercise(essential: @essential, title: "Méiose", description: "Deux divisions successives.",
                                    exercise_type: "evaluation", questions: 0)
        @second = add_question(position: 2, content: "La méiose produit des cellules haploïdes.", question_type: "true_false",
                               explanation: "n chromosomes.", answers: [ [ "Vrai", true ], [ "Faux", false ] ])
        @first = add_question(position: 1, content: "Combien de divisions ?", question_type: "single_choice",
                              explanation: "Méiose I, puis méiose II.", answers: [ [ "Une", false ], [ "Deux", true ], [ "Trois", false ] ])
      end

      def detail(reveal:, public_id: @exercise.public_id) = ExerciseDetailQuery.new.call(public_id:, reveal:)

      def add_question(position:, content:, question_type:, explanation:, answers:)
        @exercise.questions.create!(position:, content:, question_type:, explanation:).tap do |question|
          answers.reverse.each_with_index do |(text, correct), index|
            question.answers.create!(position: answers.size - index, content: text, correct:)
          end
        end
      end

      test "l'exercice, sa fiche, son cours et ses questions dans l'ordre, propositions correctes marquées avec reveal" do
        row = detail(reveal: true)

        assert_equal [ @exercise.public_id, "Méiose", "Deux divisions successives.", "evaluation", "published" ],
                     row.exercise.to_h.values_at(:public_id, :title, :description, :exercise_type, :status)
        assert_equal [ @essential.slug, "La méiose" ], row.essential.to_h.values_at(:slug, :name)
        assert_equal [ @essential.course.slug, "Génétique et évolution", "Tle", "D", "SVT", "science" ],
                     row.course.to_h.values_at(:slug, :name, :level_name, :series_name, :material_name, :material_category)
        assert_equal [ [ @first.id, 1, "Combien de divisions ?", "single_choice", "Méiose I, puis méiose II." ],
                       [ @second.id, 2, "La méiose produit des cellules haploïdes.", "true_false", "n chromosomes." ] ],
                     row.questions.map { it.to_h.values_at(:id, :position, :content, :question_type, :explanation) }
        assert_equal [ [ 1, "Une", false ], [ 2, "Deux", true ], [ 3, "Trois", false ] ],
                     row.questions.first.answers.map { it.to_h.values_at(:position, :content, :correct) }
        assert_equal @first.answers.order(:position).pluck(:id), row.questions.first.answers.map(&:id)
        assert_equal [ true, false ], row.questions.last.answers.map(&:correct)
      end

      test "sans reveal, ni la colonne correct ni l'explication ne sont lues" do
        statements = []
        collector = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }

        row = ActiveSupport::Notifications.subscribed(collector, "sql.active_record") { detail(reveal: false) }

        assert_equal [ [ "Une", nil ], [ "Deux", nil ], [ "Trois", nil ] ],
                     row.questions.first.answers.map { it.to_h.values_at(:content, :correct) }
        assert_equal [ nil, nil ], row.questions.map(&:explanation)
        assert_equal [ "Combien de divisions ?", "La méiose produit des cellules haploïdes." ], row.questions.map(&:content)
        assert statements.any? { it.include?('"answers"') }, "les propositions sont bien lues"
        assert statements.none? { it.match?(/correct|explanation/) }, "une colonne de correction a été lue : #{statements.join("\n")}"
      end

      test "trois requêtes, quel que soit le nombre de questions" do
        count = ->(reveal) { count_queries { detail(reveal:) } }

        assert_equal 3, count.call(true)
        3.times { |index| add_question(position: index + 3, content: "Q#{index}", question_type: "true_false", explanation: nil,
                                       answers: [ [ "Vrai", true ], [ "Faux", false ] ]) }
        assert_equal 3, count.call(true)
        assert_equal 3, count.call(false)
      end

      test "un cours sans série, un exercice brouillon sans question ni description" do
        exercise = create_exercise(essential: create_essential(course: create_course(series: nil)), status: "draft", questions: 0)

        row = ExerciseDetailQuery.new.call(public_id: exercise.public_id, reveal: true)

        assert_nil row.course.series_name
        assert_nil row.exercise.description
        assert_equal "draft", row.exercise.status
        assert_empty row.questions
      end

      test "un exercice inconnu donne nil" do
        assert_nil detail(reveal: true, public_id: "inconnu")
      end

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end
    end
  end
end
