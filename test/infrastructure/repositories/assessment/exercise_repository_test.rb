require "test_helper"

module Repositories
  module Assessment
    class ExerciseRepositoryTest < ActiveSupport::TestCase
      Answer = Entities::Assessment::Answer
      Question = Entities::Assessment::Question

      setup do
        @repository = ExerciseRepository.new
        @essential = create_essential
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def question(content, question_type: "true_false", answers: [ [ "Vrai", true ], [ "Faux", false ] ], position: nil)
        Question.new(id: nil, position:, content:, explanation: "Parce que.", question_type:,
                     answers: answers.map { |text, correct| Answer.new(id: nil, position: nil, content: text, correct:) })
      end

      def exercise(title: "Quiz", questions: [ question("La mitose donne deux cellules.") ], **attributes)
        Entities::Assessment::Exercise.new(essential_id: @essential.id, author_id: @essential.author_id, title:,
                                           exercise_type: "fixation", questions:, **attributes)
      end

      test "crée un exercice brouillon en fin de fiche, avec ses questions et propositions ordonnées" do
        create_exercise(essential: @essential)

        created = @repository.create(exercise: exercise(questions: [ question("Q1"), question("Q2") ]))

        assert_instance_of Entities::Assessment::Exercise, created
        assert_equal [ "draft", 2, 14 ], [ created.status, created.position, created.public_id.length ]
        assert_equal [ [ 1, "Q1" ], [ 2, "Q2" ] ], created.questions.map { [ it.position, it.content ] }
        assert_equal [ [ 1, "Vrai", true ], [ 2, "Faux", false ] ], created.questions.first.answers.map { [ it.position, it.content, it.correct ] }
        assert created.parents_published
        assert created.publishable?
      end

      test "écrit et relit la marge d'un nombre et le côté droit des paires (ADR-0091)" do
        number = Question.new(id: nil, position: nil, content: "Combien ?", explanation: nil, question_type: "numeric",
                              numeric_tolerance: BigDecimal("0.05"), answers: [ Answer.new(id: nil, position: nil, content: "3,5", correct: true) ])
        pairs = Question.new(id: nil, position: nil, content: "Relie.", explanation: nil, question_type: "matching",
                             answers: %w[a b c].map { Answer.new(id: nil, position: nil, content: it, correct: true, match_content: it.upcase) })

        created = @repository.create(exercise: exercise(questions: [ number, pairs ]))

        assert_equal [ BigDecimal("0.05"), nil ], created.questions.map(&:numeric_tolerance)
        assert_equal %w[A B C], created.questions.last.answers.map(&:match_content)
        assert_nil created.questions.first.answers.first.match_content
      end

      test "garde la position et le statut fournis" do
        created = @repository.create(exercise: exercise(position: 9, status: "published", questions: [ question("Q", position: 4) ]))

        assert_equal [ 9, "published", 4 ], [ created.position, created.status, created.questions.first.position ]
      end

      test "relit un exercice par public_id avec la publication de ses parents, nil sinon" do
        draft_parent = create_exercise(essential: create_essential(status: "draft"))

        assert_not @repository.find_by_public_id(public_id: draft_parent.public_id).parents_published
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
      end

      test "relit un exercice par id avec ses questions et la publication de ses parents, nil sinon" do
        record = create_exercise(essential: create_essential(status: "draft"))
        found = @repository.find(id: record.id)

        assert_equal [ record.public_id, record.questions.count ], [ found.public_id, found.questions.size ]
        assert_not found.parents_published
        assert_nil @repository.find(id: 0)
      end

      test "met à jour l'exercice seul, ou remplace aussi ses questions" do
        created = @repository.create(exercise: exercise)
        created.title = "Quiz révisé"
        created.questions = [ question("Nouvelle", question_type: "single_choice", answers: [ [ "A", false ], [ "B", true ] ]) ]

        kept = @repository.update(exercise: created, replace_questions: false)

        assert_equal "Quiz révisé", kept.title
        assert_equal [ "La mitose donne deux cellules." ], kept.questions.map(&:content)

        replaced = @repository.update(exercise: created, replace_questions: true)

        assert_equal [ "Nouvelle" ], replaced.questions.map(&:content)
        assert_equal 2, Orm::Answer.joins(:question).where(questions: { exercise_id: created.id }).count
      end

      test "publie en posant published_at une seule fois, archive en posant archived_at" do
        record = create_exercise(essential: @essential, status: "draft")

        assert @repository.transition(id: record.id, to: "published", at: @at)
        assert @repository.transition(id: record.id, to: "archived", at: @at + 1.day)
        @repository.transition(id: record.id, to: "published", at: @at + 2.days)

        assert_equal [ "published", @at, nil ], record.reload.attributes.values_at("status", "published_at", "archived_at")
        assert_raises(ArgumentError) { @repository.transition(id: record.id, to: "draft", at: @at) }
      end

      test "sait si un exercice a des sessions" do
        record = create_exercise(essential: @essential)

        assert_not @repository.has_sessions?(exercise_id: record.id)
        create_exercise_session(exercise: record)
        assert @repository.has_sessions?(exercise_id: record.id)
      end

      test "donne les clés de doublon, pour les fiches demandées ou toutes" do
        create_exercise(essential: @essential, title: "Quiz  Génétique")
        other = create_exercise(title: "Autre")

        assert_equal Set[[ @essential.id, "quiz genetique" ]], @repository.existing_keys(essential_ids: [ @essential.id ])
        assert_includes @repository.existing_keys, [ other.essential_id, "autre" ]
      end

      test "donne la prochaine position libre de chaque fiche" do
        create_exercise(essential: @essential, position: 3)
        empty = create_essential

        assert_equal({ @essential.id => 4, empty.id => 1 }, @repository.next_positions(essential_ids: [ @essential.id, empty.id ]))
      end

      test "la position est partagée par la leçon : la prochaine suit toutes ses notions" do
        sibling = create_essential(course: @essential.course)
        create_exercise(essential: @essential, position: 3)

        assert_equal({ sibling.id => 4 }, @repository.next_positions(essential_ids: [ sibling.id ]))
      end

      test "ADR-XXXX : crée un exercice de notion rattaché à la leçon de sa notion, avec son sujet" do
        created = @repository.create(exercise: exercise(statement: "Soit ABC un triangle."))

        assert_equal [ @essential.course_id, @essential.id, "Soit ABC un triangle.", false ],
                     [ created.course_id, created.essential_id, created.statement, created.lesson_wide? ]
      end

      test "ADR-XXXX : crée un exercice de toute la leçon sans notion, après les autres" do
        create_exercise(essential: @essential)
        lesson = Entities::Assessment::Exercise.new(course_id: @essential.course_id, author_id: @essential.author_id, title: "Bilan",
                                                    exercise_type: "evaluation", questions: [ question("Q") ])

        created = @repository.create(exercise: lesson)

        assert_nil created.essential_id
        assert_predicate created, :lesson_wide?
        assert_equal [ 2, true ], [ created.position, created.parents_published ]
      end

      test "ADR-XXXX : refuse une notion d'une autre leçon" do
        other_course = create_course

        assert_raises(Ports::Assessment::ExerciseRepositoryPort::EssentialOutsideCourse) do
          @repository.create(exercise: exercise(course_id: other_course.id))
        end
        assert_equal 0, Orm::Exercise.where(course_id: other_course.id).count
      end

      test "ADR-XXXX : for_course liste les exercices de notion dans l'ordre des notions, puis ceux de toute la leçon" do
        course = @essential.course
        second = create_essential(course:)
        lesson = create_lesson_wide_exercise(course:)
        of_second = create_exercise(essential: second)
        of_first = create_exercise(essential: @essential)
        create_exercise # another course

        listed = @repository.for_course(course_id: course.id)

        assert_equal [ of_first, of_second, lesson ].map(&:public_id), listed.map(&:public_id)
        assert_equal [ false, false, true ], listed.map(&:lesson_wide?)
        assert_equal [ 2, 2, 2 ], listed.map { it.questions.size }
      end

      # ADR-0035, amendement du 2026-10-01 (« Tout publier ») : les exercices brouillons sous des fiches publiées, dans
      # l'ordre des fiches puis des exercices ; ceux d'une fiche brouillon ou archivée attendent leur fiche.
      test "draft_public_ids liste les exercices brouillons des fiches publiées d'un cours, ou d'une fiche" do
        course = create_course
        first = create_essential(course:, position: 1)
        second = create_essential(course:, position: 2)
        drafted = create_essential(course:, position: 3, status: "draft")
        b = create_exercise(essential: first, status: "draft", position: 2)
        a = create_exercise(essential: first, status: "draft", position: 1)
        c = create_exercise(essential: second, status: "draft")
        create_exercise(essential: first, status: "published")
        create_exercise(essential: second, status: "archived")
        create_exercise(essential: drafted, status: "draft")
        create_exercise(essential: create_essential, status: "draft")
        repository = Repositories::Assessment::ExerciseRepository.new

        assert_equal [ a, b, c ].map(&:public_id), repository.draft_public_ids(course_id: course.id)
        assert_equal [ a, b ].map(&:public_id), repository.draft_public_ids(essential_id: first.id)
        assert_empty repository.draft_public_ids(essential_id: drafted.id)
      end

      # ADR-0105 : une question cite son image par public_id ; l'enregistrement la rattache (si elle n'est à personne), écrit
      # son texte de remplacement, et supprime l'image remplacée ou retirée. FK RESTRICT : une question remplacée perd son
      # image avant de partir.
      test "ADR-XXXX : « Tout publier » suit aussi les exercices de toute la leçon, après ceux des notions" do
        course = @essential.course
        of_essential = create_exercise(essential: @essential, status: "draft")
        lesson = create_lesson_wide_exercise(course:, status: "draft")
        create_exercise(essential: create_essential(course:, status: "draft"), status: "draft")

        assert_equal [ of_essential, lesson ].map(&:public_id), @repository.draft_public_ids(course_id: course.id)
      end

      def illustrated(content, image: nil, alt: nil, description: nil)
        question(content).with(image_description: description,
                               image: image && Entities::Shared::ContentImage.new(public_id: image.public_id, alt:))
      end

      test "ADR-0105 : crée un exercice dont une question porte son image et sa description, relues" do
        image = create_question_image(fixture: "photos/photo.png")

        created = @repository.create(exercise: exercise(questions: [ illustrated("Q1", image:, alt: "Une pile", description: "Un circuit"),
                                                                     illustrated("Q2", description: "Une lampe") ]))

        first, second = created.questions
        assert_equal [ image.public_id, "Une pile", "image/png", "Un circuit" ],
                     [ first.image.public_id, first.image.alt, first.image.content_type, first.image_description ]
        assert_equal [ nil, "Une lampe" ], [ second.image, second.image_description ]
        assert_equal Orm::Question.find_by!(exercise_id: created.id, position: 1).id, image.reload.question_id
      end

      test "ADR-0105 : remplacer les questions garde l'image citée, supprime la remplacée et le journalise" do
        kept = create_question_image
        replaced = create_question_image
        fresh = create_question_image
        created = @repository.create(exercise: exercise(questions: [ illustrated("Q1", image: kept, alt: "a"),
                                                                     illustrated("Q2", image: replaced, alt: "b") ]))

        logs = capture_log do
          @updated = @repository.update(exercise: exercise(id: created.id, questions: [ illustrated("Q1", image: kept, alt: "a2"),
                                                                                        illustrated("Q2", image: fresh, alt: "c") ]),
                                        replace_questions: true)
        end

        assert_equal [ [ kept.public_id, "a2" ], [ fresh.public_id, "c" ] ], @updated.questions.map { [ it.image.public_id, it.image.alt ] }
        assert_not Orm::QuestionImage.exists?(replaced.id)
        assert_includes logs, "[ExerciseRepository] images supprimées ids=[#{replaced.id}] public_ids=[\"#{replaced.public_id}\"]"
      end

      test "ADR-0105 : une image d'un autre exercice, citée deux fois ou inconnue refuse l'écriture au lieu d'être perdue" do
        foreign = create_question_image(question: create_exercise.questions.first)
        twice = create_question_image
        unknown = Struct.new(:public_id).new("inconnue")

        [ [ illustrated("Q1", image: foreign, alt: "a") ],
          [ illustrated("Q1", image: twice, alt: "a"), illustrated("Q2", image: twice, alt: "b") ],
          [ illustrated("Q1", image: unknown, alt: "a") ] ].each do |questions|
          assert_raises(Ports::Assessment::ExerciseRepositoryPort::ImageUnavailable) do
            Repositories::Shared::Transaction.new.attempt { @repository.create(exercise: exercise(questions:)) }
          end
        end
        assert_equal foreign.question_id, foreign.reload.question_id
        assert_nil twice.reload.question_id
      end

      test "ADR-0105 : une question réécrite sans description d'image n'en garde aucune" do
        created = @repository.create(exercise: exercise(questions: [ illustrated("Q1", description: "Un circuit") ]))

        updated = @repository.update(exercise: exercise(id: created.id, questions: [ illustrated("Q1") ]), replace_questions: true)

        assert_nil updated.questions.first.image_description
      end

      test "ADR-0105 : retirer toutes les questions supprime leurs images sans heurter la clé étrangère" do
        image = create_question_image
        created = @repository.create(exercise: exercise(questions: [ illustrated("Q1", image:, alt: "a") ]))

        @repository.update(exercise: exercise(id: created.id, questions: [ question("Q") ]), replace_questions: true)

        assert_not Orm::QuestionImage.exists?(image.id)
      end
    end
  end
end
