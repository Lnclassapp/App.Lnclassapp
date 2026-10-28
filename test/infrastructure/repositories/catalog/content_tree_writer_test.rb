require "test_helper"

module Repositories
  module Catalog
    class ContentTreeWriterTest < ActiveSupport::TestCase
      Port = Ports::Catalog::ContentTreeWriterPort

      setup do
        @writer = ContentTreeWriter.new
        @author = create_team_member(team_role: "content", second_factor: false)
        @level = create_level
        @material = create_material
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def answers
        [ Port::AnswerNode.new(position: 1, content: "Vrai", correct: true), Port::AnswerNode.new(position: 2, content: "Faux", correct: false) ]
      end

      def exercise(title, essential_id: nil, position: 1)
        questions = [ 1, 2 ].map do |rank|
          Port::QuestionNode.new(position: rank, content: "#{title} Q#{rank}", explanation: nil, question_type: "true_false", answers:)
        end
        Port::ExerciseNode.new(public_id: SecureRandom.base58(14), essential_id:, title:, statement: nil,
                               exercise_type: "fixation", position:, questions:)
      end

      def essential(slug, course_id: nil, position: 1, content: "<p>Fiche #{slug}</p>")
        Port::EssentialNode.new(slug:, course_id:, name: "Fiche #{slug}", subtitle: nil, content:, position:,
                                exercises: [ exercise("Quiz #{slug}", position: 1), exercise("Défi #{slug}", position: 2) ])
      end

      def course(slug, content:, exercises: [])
        Port::CourseNode.new(slug:, name: "Cours #{slug}", subtitle: "Sous-titre", content:, level_id: @level.id, series_id: nil,
                             material_id: @material.id, essentials: [ essential("#{slug}-a", position: 1), essential("#{slug}-b", position: 2) ],
                             exercises:)
      end

      test "écrit deux cours complets, parents d'abord, tout en draft, et compte les lignes créées" do
        counts = @writer.write(author_id: @author.id, at: @at,
                               courses: [ course("genetique", content: "<p>Hérédité</p>"), course("ecologie", content: nil) ])

        assert_equal({ courses: 2, essentials: 4, exercises: 8, questions: 16, answers: 32 }, counts)
        genetique = Orm::Course.find_by!(slug: "genetique")
        assert_equal [ "genetique-a", "genetique-b" ], genetique.essentials.order(:position).pluck(:slug)
        essential = Orm::Essential.find_by!(slug: "genetique-b")
        # La position est unique par leçon : les deux notions se suivent (a : 1, 2 ; b : 3, 4).
        assert_equal [ [ 3, "Quiz genetique-b" ], [ 4, "Défi genetique-b" ] ], essential.exercises.order(:position).pluck(:position, :title)
        question = essential.exercises.find_by!(position: 4).questions.find_by!(position: 2)
        assert_equal [ "Défi genetique-b Q2", [ [ 1, "Vrai", true ], [ 2, "Faux", false ] ] ],
                     [ question.content, question.answers.order(:position).pluck(:position, :content, :correct) ]
        [ Orm::Course, Orm::Essential, Orm::Exercise ].each do |model|
          assert_equal [ [ "draft", @author.id, @at ] ], model.distinct.pluck(:status, :author_id, :created_at), model
        end
        assert_equal [ @at ], Orm::Answer.distinct.pluck(:updated_at)
      end

      # ADR-0113 §4.1 : un exercice de toute la leçon n'a pas de notion ; il prend la leçon du cours et suit les exercices des notions.
      test "les exercices de toute la leçon n'ont pas de notion, portent la leçon du cours et se placent après ceux des notions" do
        lesson_wide = [ exercise("Bilan 1"), exercise("Bilan 2") ]

        counts = @writer.write(author_id: @author.id, at: @at, courses: [ course("genetique", content: nil, exercises: lesson_wide),
                                                                          course("ecologie", content: nil, exercises: [ exercise("Bilan écologie") ]) ])

        assert_equal({ courses: 2, essentials: 4, exercises: 11, questions: 22, answers: 44 }, counts)
        genetique = Orm::Course.find_by!(slug: "genetique")
        assert_equal [ [ 1, "Quiz genetique-a" ], [ 2, "Défi genetique-a" ], [ 3, "Quiz genetique-b" ], [ 4, "Défi genetique-b" ], [ 5, "Bilan 1" ], [ 6, "Bilan 2" ] ],
                     Orm::Exercise.where(course_id: genetique.id).order(:position).pluck(:position, :title)
        assert_equal [ [ nil, "draft" ], [ nil, "draft" ] ], Orm::Exercise.where(course_id: genetique.id, title: [ "Bilan 1", "Bilan 2" ]).pluck(:essential_id, :status)
        assert_equal [ [ 5, "Bilan écologie" ] ], Orm::Exercise.where(course_id: Orm::Course.find_by!(slug: "ecologie").id, essential_id: nil).pluck(:position, :title)
        assert_equal [ 2, 2 ], Orm::Exercise.find_by!(title: "Bilan 1").questions.then { [ it.count, it.first.answers.count ] }
      end

      test "des exercices de toute la leçon dans un cours sans notion s'écrivent aussi" do
        counts = @writer.write(author_id: @author.id, at: @at, courses: [ course("seul", content: nil, exercises: [ exercise("Bilan") ]).with(essentials: []) ])

        assert_equal({ courses: 1, essentials: 0, exercises: 1, questions: 2, answers: 4 }, counts)
        assert_equal [ [ 1, nil ] ], Orm::Exercise.pluck(:position, :essential_id)
      end

      test "le contenu riche est assaini ; un contenu vide ne crée pas de ligne" do
        dirty = %(<p onclick="x()">Hérédité <script>alert(1)</script><strong>forte</strong></p>)

        @writer.write(author_id: @author.id, at: @at, courses: [ course("genetique", content: dirty), course("ecologie", content: " ") ])

        assert_equal "<p>Hérédité <strong>forte</strong></p>", Orm::Course.find_by!(slug: "genetique").content.body.to_html
        assert_nil ActionText::RichText.find_by(record: Orm::Course.find_by!(slug: "ecologie"))
        assert_equal "<p>Fiche ecologie-a</p>", Orm::Essential.find_by!(slug: "ecologie-a").content.body.to_html
        assert_equal [ "Orm::Course", "Orm::Essential" ], ActionText::RichText.distinct.order(:record_type).pluck(:record_type)
      end

      # ADR-0068 §4 : deux chemins d'écriture des contenus riches, Orm::RichTextRow pour l'import, le modèle Action Text
      # pour les formulaires. Le corps stocké est le même, octet pour octet.
      test "le corps écrit sans conversion est celui qu'Action Text aurait écrit" do
        contents = [ "\n  <p>Espaces autour</p>\n\n", "<h2>Titre</h2>\n<ul>\n<li>un</li>\n</ul>\n", "<p>a &amp; b &nbsp;é 😀 $\\frac{1}{2}$</p>" ]

        @writer.write(author_id: @author.id, at: @at, courses: contents.each_with_index.map { |html, index| course("c#{index}", content: html) })

        contents.each_with_index do |html, index|
          stored = ActionText::RichText.connection.select_value(
            "SELECT body FROM action_text_rich_texts WHERE record_type = 'Orm::Course' AND record_id = #{Orm::Course.find_by!(slug: "c#{index}").id}"
          )
          assert_equal ActionText::Content.new(Repositories::Shared::RichTextSanitizer.call(html)).to_html, stored
        end
      end

      test "écrit des fiches dans un cours existant, ou des exercices dans une fiche existante" do
        target = create_course
        fiche = create_essential(course: target, position: 1)

        counts = @writer.write(author_id: @author.id, at: @at, essentials: [ essential("fiche-importee", course_id: target.id, position: 2) ],
                               exercises: [ exercise("Isolé", essential_id: fiche.id, position: 5) ])

        assert_equal({ courses: 0, essentials: 1, exercises: 3, questions: 6, answers: 12 }, counts)
        assert_equal [ 1, 2 ], target.essentials.order(:position).pluck(:position)
        assert_equal [ "Isolé" ], fiche.exercises.pluck(:title)
      end

      test "écrire des exercices seuls ne touche à aucune autre table de contenu" do
        fiche = create_essential

        assert_no_difference [ "Orm::Course.count", "Orm::Essential.count", "ActionText::RichText.count" ] do
          @writer.write(author_id: @author.id, at: @at, exercises: [ exercise("Seul", essential_id: fiche.id, position: 3) ])
        end
      end

      test "sans nœud, rien n'est écrit ; une ligne refusée par la base lève" do
        assert_equal({ courses: 0, essentials: 0, exercises: 0, questions: 0, answers: 0 }, @writer.write(author_id: @author.id, at: @at))

        create_course(slug: "genetique")

        assert_raises(ActiveRecord::RecordNotUnique) do
          @writer.write(author_id: @author.id, at: @at, courses: [ course("genetique", content: nil) ])
        end
      end

      def question(content, position: 1, explanation: nil, question_type: "true_false", answers: self.answers)
        Port::QuestionNode.new(position:, content:, explanation:, question_type:, answers:)
      end

      def exercise_with(questions, essential_id:, statement: nil, public_id: SecureRandom.base58(14), position: 9)
        Port::ExerciseNode.new(public_id:, essential_id:, title: "Échappement", statement:, exercise_type: "fixation", position:, questions:)
      end

      # ADR-0068 §5 : un caractère mal échappé au format texte de COPY corromprait une ligne.
      test "questions et propositions écrites par COPY se relisent à l'identique, caractères spéciaux compris" do
        fiche = create_essential
        tricky = "tab\tici, ligne\nsuivante, retour\r\nchariot, barre \\ oblique, \\N, $\\frac{1}{2}$, « guillemets » \"doubles\" 'simples', 😀"
        answers = [ Port::AnswerNode.new(position: 1, content: tricky, correct: true), Port::AnswerNode.new(position: 2, content: "\\", correct: false) ]
        questions = [ question(tricky, explanation: nil, answers:), question("Deuxième", position: 2, explanation: "Pour\tla\nraison \\x") ]
        at = Time.zone.parse("2026-09-25 10:00:00.123456789").in_time_zone("Pacific/Auckland")

        counts = @writer.write(author_id: @author.id, at:, exercises: [ exercise_with(questions, essential_id: fiche.id, statement: tricky) ])

        assert_equal({ courses: 0, essentials: 0, exercises: 1, questions: 2, answers: 4 }, counts)
        exercise = fiche.exercises.find_by!(position: 1)
        assert_equal [ "Échappement", tricky, "draft", @author.id ], [ exercise.title, exercise.statement, exercise.status, exercise.author_id ]
        written = exercise.questions.order(:position)
        assert_equal [ [ 1, tricky, nil, "true_false" ], [ 2, "Deuxième", "Pour\tla\nraison \\x", "true_false" ] ],
                     written.pluck(:position, :content, :explanation, :question_type)
        assert_equal [ [ 1, tricky, true ], [ 2, "\\", false ] ], written.first.answers.order(:position).pluck(:position, :content, :correct)
        assert_equal written.map(&:id).sort, written.map(&:id)
        assert_equal [ exercise.created_at ], (written.pluck(:created_at, :updated_at).flatten + Orm::Answer.where(question: written).pluck(:created_at)).uniq
        assert_equal Time.zone.parse("2026-09-25 10:00:00.123456"), exercise.created_at
      end

      test "la marge d'un nombre et le côté droit d'une paire s'écrivent par COPY (ADR-0091)" do
        fiche = create_essential
        number = Port::QuestionNode.new(position: 1, content: "Combien ?", explanation: nil, question_type: "numeric",
                                        numeric_tolerance: BigDecimal("0.1"), answers: [ Port::AnswerNode.new(position: 1, content: "3,5", correct: true) ])
        pairs = question("Relie.", position: 2, question_type: "matching",
                         answers: [ Port::AnswerNode.new(position: 1, content: "a", correct: true, match_content: "tab\tA") ])

        @writer.write(author_id: @author.id, at: Time.current, exercises: [ exercise_with([ number, pairs ], essential_id: fiche.id) ])

        written = fiche.exercises.sole.questions.order(:position)
        assert_equal [ BigDecimal("0.1"), nil ], written.map(&:numeric_tolerance)
        assert_equal [ [ nil ], [ "tab\tA" ] ], written.map { it.answers.map(&:match_content) }
      end

      # Un refus de la base pendant un COPY lève l'erreur qu'ActiveRecord aurait levée : le moteur rejoue alors le lot
      # élément par élément, et le cours refusé n'est jamais écrit à moitié.
      test "une contrainte refusée par COPY lève l'erreur d'ActiveRecord et n'écrit rien du cours" do
        fiche = create_essential
        twin = SecureRandom.base58(14)
        refusals = [
          [ ActiveRecord::RecordNotUnique, [ exercise_with([], essential_id: fiche.id, public_id: twin),
                                             exercise_with([], essential_id: fiche.id, public_id: twin, position: 10) ] ],
          [ ActiveRecord::RecordNotUnique, [ exercise_with([ question("Q1"), question("Q1 bis") ], essential_id: fiche.id) ] ],
          [ ActiveRecord::CheckViolation, [ exercise_with([ question("Q", question_type: "inconnu") ], essential_id: fiche.id) ] ],
          [ ActiveRecord::ValueTooLong, [ exercise_with([ question("Q", answers: [ Port::AnswerNode.new(position: 1, content: "x" * 501, correct: true) ]) ],
                                                        essential_id: fiche.id) ] ]
        ]
        refusals.each do |error, exercises|
          assert_raises(error) do
            ActiveRecord::Base.transaction(requires_new: true) { @writer.write(author_id: @author.id, at: @at, exercises:) }
          end
        end

        bad = course("genetique", content: "<p>x</p>").then do |node|
          node.with(essentials: [ node.essentials.first.with(exercises: [ exercise_with([ question("Q", question_type: "inconnu") ], essential_id: nil) ]) ])
        end
        assert_no_difference [ "Orm::Course.count", "Orm::Essential.count", "Orm::Exercise.count", "Orm::Question.count", "ActionText::RichText.count" ] do
          assert Repositories::Shared::Transaction.new.attempt { @writer.write(author_id: @author.id, at: @at, courses: [ bad ]) }.failure?
        end
        assert Repositories::Shared::Transaction.new.attempt { @writer.write(author_id: @author.id, at: @at, courses: [ course("ecologie", content: nil) ]) }.success?
        assert_equal 8, Orm::Question.joins(exercise: { essential: :course }).where(courses: { slug: "ecologie" }).count
      end
    end
  end
end
