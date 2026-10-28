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
        @exercise = create_exercise(essential: @essential, title: "Méiose", statement: "Deux divisions successives.",
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
                     row.exercise.to_h.values_at(:public_id, :title, :statement, :exercise_type, :status)
        assert_equal [ @essential.slug, "La méiose" ], row.essential.to_h.values_at(:slug, :name)
        assert_equal [ @essential.course.slug, "Génétique et évolution", "Tle", "D", "SVT", "science" ],
                     row.course.to_h.values_at(:slug, :name, :level_name, :series_name, :material_name, :material_category)
        assert_equal [ [ @first.id, 1, "Combien de divisions ?", "single_choice", "Méiose I, puis méiose II." ],
                       [ @second.id, 2, "La méiose produit des cellules haploïdes.", "true_false", "n chromosomes." ] ],
                     row.questions.map { it.to_h.values_at(:id, :position, :content, :question_type, :explanation) }
        # UDR-0138 §3.1 : l'ordre affiché est le mélange de la graine de l'exercice, pas l'ordre de saisie.
        assert_equal [ [ 1, "Une", false ], [ 2, "Deux", true ], [ 3, "Trois", false ] ],
                     row.questions.first.answers.map { it.to_h.values_at(:position, :content, :correct) }.sort
        assert_equal @first.answers.order(:position).pluck(:id).sort, row.questions.first.answers.map(&:id).sort
        assert_equal [ false, true ], row.questions.last.answers.map(&:correct).sort_by(&:to_s)
      end

      test "sans reveal, ni la colonne correct ni l'explication ne sont lues" do
        statements = []
        collector = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }

        row = ActiveSupport::Notifications.subscribed(collector, "sql.active_record") { detail(reveal: false) }

        assert_equal [ [ "Deux", nil ], [ "Trois", nil ], [ "Une", nil ] ],
                     row.questions.first.answers.map { it.to_h.values_at(:content, :correct) }.sort
        assert_equal [ nil, nil ], row.questions.map(&:explanation)
        assert_equal [ "Combien de divisions ?", "La méiose produit des cellules haploïdes." ], row.questions.map(&:content)
        assert statements.any? { it.include?('"answers"') }, "les propositions sont bien lues"
        assert statements.none? { it.match?(/correct|explanation/) }, "une colonne de correction a été lue : #{statements.join("\n")}"
      end

      test "quatre requêtes, quel que soit le nombre de questions" do
        count = ->(reveal) { count_queries { detail(reveal:) } }

        assert_equal 4, count.call(true)
        3.times { |index| add_question(position: index + 3, content: "Q#{index}", question_type: "true_false", explanation: nil,
                                       answers: [ [ "Vrai", true ], [ "Faux", false ] ]) }
        create_kind_question(exercise: @exercise, question_type: "ordering", answers: %w[a b c])
        assert_equal 5, count.call(true)
        assert_equal 5, count.call(false)
      end

      # CA-14 : un exercice de toute la leçon n'a pas de notion ; il se lit par son cours.
      test "un exercice de toute la leçon : pas de notion, le cours et le sujet" do
        lesson = create_lesson_wide_exercise(course: @essential.course, statement: "Soit un triangle ABC.")

        row = detail(reveal: false, public_id: lesson.public_id)

        assert_nil row.essential
        assert_equal [ @essential.course.slug, "Soit un triangle ABC." ], [ row.course.slug, row.exercise.statement ]
        assert_equal lesson.id, row.exercise.id
      end

      # UDR-0138 §3.1 : la feuille de l'élève montre les étapes mélangées et les deux colonnes, sans solution ni identifiant.
      test "ordre et relier sans reveal : étapes et colonne de droite mélangées de la graine de l'exercice, jamais dans l'ordre juste" do
        order = create_kind_question(exercise: @exercise, question_type: "ordering", answers: %w[un deux trois quatre])
        pairs = create_kind_question(exercise: @exercise, question_type: "matching", answers: [ %w[a 1], %w[b 2], %w[c 3] ])

        first = detail(reveal: false).questions.find { it.id == order.id }
        matching = detail(reveal: false).questions.find { it.id == pairs.id }

        assert_equal %w[deux quatre trois un], first.items.map(&:content).sort
        assert_not_equal %w[un deux trois quatre], first.items.map(&:content)
        assert_equal [ 0, 1, 2, 3 ], first.items.map(&:index)
        assert_equal first.items, detail(reveal: false).questions.find { it.id == order.id }.items
        assert_equal %w[a b c], matching.prompts
        assert_not_equal %w[1 2 3], matching.items.map(&:content)
        assert_equal %w[1 2 3], matching.items.map(&:content).sort
        assert_empty first.answers
        assert_empty matching.answers
      end

      test "l'image d'une question" do
        image = create_question_image(question: @first)

        found = detail(reveal: false).questions.first.image

        assert_equal [ image.public_id, nil ], [ found.public_id, detail(reveal: false).questions.last.image ]
      end

      test "un cours sans série, un exercice brouillon sans question ni description" do
        exercise = create_exercise(essential: create_essential(course: create_course(series: nil)), status: "draft", questions: 0)

        row = ExerciseDetailQuery.new.call(public_id: exercise.public_id, reveal: true)

        assert_nil row.course.series_name
        assert_nil row.exercise.statement
        assert_equal "draft", row.exercise.status
        assert_empty row.questions
      end

      # CA-16, ADR-0091 §4.4 : l'élève voit l'énoncé et le type, ni valeur ni ordre ; l'enseignant voit la solution.
      test "nouveaux types : aucun élément sans reveal ; avec reveal, les éléments, la marge et le côté droit des paires" do
        number = create_kind_question(exercise: @exercise, question_type: "numeric", answers: [ "3,5" ], numeric_tolerance: BigDecimal("0.1"))
        pairs = create_kind_question(exercise: @exercise, question_type: "matching", answers: [ %w[a 1], %w[b 2], %w[c 3] ])

        hidden = detail(reveal: false).questions.last(2)
        assert_equal [ [], [] ], hidden.map(&:answers)
        assert_equal [ nil, %w[numeric matching] ], [ hidden.first.numeric_tolerance, hidden.map(&:kind_name) ]

        shown = detail(reveal: true).questions.last(2)
        assert_equal [ number.id, BigDecimal("0.1"), [ "3,5" ] ], [ shown.first.id, shown.first.numeric_tolerance, shown.first.answers.map(&:content) ]
        assert_equal [ pairs.id, %w[1 2 3] ], [ shown.last.id, shown.last.answers.map(&:match_content) ]
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
