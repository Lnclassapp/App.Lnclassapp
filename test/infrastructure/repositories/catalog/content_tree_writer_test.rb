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

        assert_equal({ courses: 2, essentials: 4, exercises: 8, questions: 16, answers: 32, archived: 0 }, counts)
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

        assert_equal({ courses: 2, essentials: 4, exercises: 11, questions: 22, answers: 44, archived: 0 }, counts)
        genetique = Orm::Course.find_by!(slug: "genetique")
        assert_equal [ [ 1, "Quiz genetique-a" ], [ 2, "Défi genetique-a" ], [ 3, "Quiz genetique-b" ], [ 4, "Défi genetique-b" ], [ 5, "Bilan 1" ], [ 6, "Bilan 2" ] ],
                     Orm::Exercise.where(course_id: genetique.id).order(:position).pluck(:position, :title)
        assert_equal [ [ nil, "draft" ], [ nil, "draft" ] ], Orm::Exercise.where(course_id: genetique.id, title: [ "Bilan 1", "Bilan 2" ]).pluck(:essential_id, :status)
        assert_equal [ [ 5, "Bilan écologie" ] ], Orm::Exercise.where(course_id: Orm::Course.find_by!(slug: "ecologie").id, essential_id: nil).pluck(:position, :title)
        assert_equal [ 2, 2 ], Orm::Exercise.find_by!(title: "Bilan 1").questions.then { [ it.count, it.first.answers.count ] }
      end

      test "des exercices de toute la leçon dans un cours sans notion s'écrivent aussi" do
        counts = @writer.write(author_id: @author.id, at: @at, courses: [ course("seul", content: nil, exercises: [ exercise("Bilan") ]).with(essentials: []) ])

        assert_equal({ courses: 1, essentials: 0, exercises: 1, questions: 2, answers: 4, archived: 0 }, counts)
        assert_equal [ [ 1, nil ] ], Orm::Exercise.pluck(:position, :essential_id)
      end

      test "le contenu riche est assaini ; un contenu vide ne crée pas de ligne" do
        dirty = %(<p onclick="x()">Hérédité <script>alert(1)</script><strong>forte</strong></p>)

        @writer.write(author_id: @author.id, at: @at, courses: [ course("genetique", content: dirty), course("ecologie", content: " ") ])

        assert_equal "<p>Hérédité <strong>forte</strong></p>", Orm::Course.find_by!(slug: "genetique").content.body.to_html
        assert_nil ActionText::RichText.find_by(record: Orm::Course.find_by!(slug: "ecologie"))
        assert_equal [ "Orm::Course" ], ActionText::RichText.distinct.order(:record_type).pluck(:record_type)
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

        assert_equal({ courses: 0, essentials: 1, exercises: 3, questions: 6, answers: 12, archived: 0 }, counts)
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
        assert_equal({ courses: 0, essentials: 0, exercises: 0, questions: 0, answers: 0, archived: 0 }, @writer.write(author_id: @author.id, at: @at))

        create_course(slug: "genetique")

        assert_raises(ActiveRecord::RecordNotUnique) do
          @writer.write(author_id: @author.id, at: @at, courses: [ course("genetique", content: nil) ])
        end
      end

      # Réimport (ADR-0113 §4.5) : existing_id archive les exercices et leurs assignations, sans réécrire la leçon.
      test "une leçon existante (existing_id) voit ses exercices et ses assignations actives archivés, puis remplacés" do
        lesson = create_course
        fiche = create_essential(course: lesson)
        old = create_exercise(essential: fiche)
        assignment = create_assignment(assignable: old)
        node = course("remplace", content: nil, exercises: [ exercise("Bilan") ]).with(slug: nil, existing_id: lesson.id, essentials: [])

        counts = @writer.write(author_id: @author.id, at: @at, courses: [ node ])

        assert_equal 1, counts[:archived]
        assert_equal [ "archived", @at ], old.reload.values_at(:status, :archived_at)
        assert_equal [ "archived", @at ], assignment.reload.values_at(:status, :archived_at)
        assert_equal [ 1, 1 ], [ Orm::Course.count, Orm::Exercise.where(status: "draft").count ]
      end

      test "une écriture qui échoue après l'archivage laisse les anciens exercices et leurs assignations intacts" do
        lesson = create_course
        old = create_exercise(essential: create_essential(course: lesson))
        assignment = create_assignment(assignable: old)
        twin = SecureRandom.base58(14)
        collision = [ exercise("Un"), exercise("Deux") ].map { it.with(public_id: twin) }
        node = course("remplace", content: nil, exercises: collision).with(slug: nil, existing_id: lesson.id, essentials: [])

        result = Repositories::Shared::Transaction.new.attempt { @writer.write(author_id: @author.id, at: @at, courses: [ node ]) }

        assert result.failure?
        assert_equal "published", old.reload.status
        assert_nil old.archived_at
        assert_equal "active", assignment.reload.status
        assert_nil assignment.archived_at
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

        assert_equal({ courses: 0, essentials: 0, exercises: 1, questions: 2, answers: 4, archived: 0 }, counts)
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

      test "le sujet en blocs d'un exercice s'écrit en JSON, sans blocs la colonne reste vide (ADR-0115)" do
        fiche = create_essential
        blocks = [ { "type" => "paragraph", "text" => "Un énoncé avec $x$." }, { "type" => "box", "label" => "Retenir", "paragraphs" => [ "Texte." ] } ]
        with_blocks = Port::ExerciseNode.new(public_id: SecureRandom.base58(14), essential_id: fiche.id, title: "Avec sujet", statement: nil,
                                             exercise_type: "fixation", position: 1, statement_blocks: blocks,
                                             questions: [ Port::QuestionNode.new(position: 1, content: "Q", explanation: nil, question_type: "true_false", answers:) ])

        @writer.write(author_id: @author.id, at: @at, exercises: [ with_blocks, exercise("Sans sujet", essential_id: fiche.id, position: 2) ])

        assert_equal [ blocks, nil ], fiche.exercises.order(:position).map(&:statement_blocks)
      end

      # --- Format 3 (ADR-0116 §4.3, §4.4) ---

      def v3_exercise(title, figure_key: nil)
        Port::ExerciseNode.new(public_id: SecureRandom.base58(14), essential_id: nil, title:, statement: "Sujet", exercise_type: "fixation",
                               position: nil, questions: [ 1, 2 ].map { |rank| Port::QuestionNode.new(position: rank, content: "#{title} Q#{rank}", explanation: "x" * 25, question_type: "true_false", answers:) },
                               figure_key:)
      end

      def v3_notion(slug, name, position, figure_key: nil)
        sheet = { "remember" => "À retenir #{name}", "method" => %w[a b], "example" => { "statement" => "e", "steps" => %w[a b] },
                  "pitfall" => "Piège", "figure_key" => figure_key }
        Port::NotionNode.new(slug:, course_id: nil, name:, position:, sheet:, exercises: [ v3_exercise("Exercice #{name}", figure_key:) ])
      end

      def v3_course(slug, existing_id: nil, notion_slug: "#{slug}-n1", notions: nil)
        figures = [ { "key" => "fig", "kind" => "geometry", "description" => "d" * 160, "params" => {}, "controls" => [] } ]
        Port::CourseNode.new(slug: (slug unless existing_id), name: "Leçon #{slug}", subtitle: nil, content: nil, level_id: @level.id, series_id: nil,
                             material_id: @material.id, essentials: [], exercises: [ v3_exercise("Problème 1"), v3_exercise("Problème 2") ],
                             existing_id:, figures:, sheet_theme: "teal",
                             notions: notions || [ v3_notion(notion_slug, "Notion 1", 1, figure_key: "fig"), v3_notion("#{notion_slug}-b", "Notion 2", 2) ])
      end

      test "écrit une leçon v3 : figures, thème, fiche des notions, figure des exercices, exercices de la leçon après ceux des notions" do
        counts = @writer.write(author_id: @author.id, at: @at, courses: [ v3_course("racines") ])

        assert_equal({ courses: 1, essentials: 2, exercises: 4, questions: 8, answers: 16, archived: 0 }, counts)
        course = Orm::Course.find_by!(slug: "racines")
        assert_equal [ "teal", [ "fig" ] ], [ course.sheet_theme, course.figures.map { it["key"] } ]
        notion = course.essentials.order(:position).first
        assert_equal [ "draft", nil, "fig", %w[a b] ], [ notion.status, notion.subtitle, notion.sheet["figure_key"], notion.sheet["method"] ]
        assert_equal [ [ 1, "Exercice Notion 1", "fig" ], [ 2, "Exercice Notion 2", nil ], [ 3, "Problème 1", nil ], [ 4, "Problème 2", nil ] ],
                     Orm::Exercise.where(course_id: course.id).order(:position).pluck(:position, :title, :figure_key)
        assert_equal [ notion.id ], Orm::Exercise.where(course_id: course.id, title: "Exercice Notion 1").pluck(:essential_id)
      end

      # CA-11
      test "replace_draft remplace la leçon entière, garde son id, son slug et son auteur, et supprime séances, tentatives, badges et lacunes" do
        @writer.write(author_id: @author.id, at: @at, courses: [ v3_course("racines") ])
        course = Orm::Course.find_by!(slug: "racines")
        old_notion = course.essentials.order(:position).first
        old_exercise = Orm::Exercise.find_by!(essential_id: old_notion.id)
        student = create_student
        session = create_exercise_session(student:, exercise: old_exercise, status: "completed")
        create_attempt(session:, question: old_exercise.questions.first)
        create_badge(student:, exercise: old_exercise, session:)
        gap = create_gap(student:, essential: old_notion, source_session: session)
        create_exercise_session(student:, exercise: Orm::Exercise.where(course_id: course.id, essential_id: nil).first, gap:)
        create_essential_read(student:, essential: old_notion)
        tree = v3_course("racines", existing_id: course.id, notion_slug: "racines-n1").with(name: "Leçon corrigée", figures: [], sheet_theme: "burgundy")

        counts = @writer.replace_draft(course_id: course.id, tree:)

        assert_equal({ courses: 1, essentials: 2, exercises: 4, questions: 8, answers: 16 }, counts)
        replaced = Orm::Course.find(course.id)
        assert_equal [ "racines", "Leçon corrigée", "burgundy", [], @author.id, "draft" ],
                     [ replaced.slug, replaced.name, replaced.sheet_theme, replaced.figures, replaced.author_id, replaced.status ]
        assert_equal [ "racines-n1", "racines-n1-b" ], replaced.essentials.order(:position).pluck(:slug)
        assert_not Orm::Essential.exists?(old_notion.id)
        assert_equal [ 1, 2, 3, 4 ], Orm::Exercise.where(course_id: course.id).order(:position).pluck(:position)
        assert_equal [ 4, 8, 16 ], [ Orm::Exercise.count, Orm::Question.count, Orm::Answer.count ]
        assert_equal [ 0, 0, 0, 0, 0 ], [ Orm::ExerciseSession, Orm::QuestionAttempt, Orm::ExerciseBadge, Orm::KnowledgeGap, Orm::EssentialRead ].map(&:count)
      end

      test "replace_draft refuse une leçon, une notion ou un exercice qui n'est plus en brouillon, et ne supprime rien" do
        @writer.write(author_id: @author.id, at: @at, courses: [ v3_course("racines") ])
        course = Orm::Course.find_by!(slug: "racines")
        tree = v3_course("racines", existing_id: course.id)
        changes = { course: -> { course.update_columns(status: "published", published_at: Time.current) },
                    essential: -> { course.essentials.first.update_columns(status: "archived", archived_at: Time.current) },
                    exercise: -> { Orm::Exercise.where(course_id: course.id).first.update_columns(status: "published", published_at: Time.current) } }
        changes.each do |name, change|
          Orm::Course.transaction(requires_new: true) do
            change.call
            assert_no_difference [ "Orm::Essential.count", "Orm::Exercise.count", "Orm::Question.count" ], name.to_s do
              assert_raises(ContentTreeWriter::NotDraft, name.to_s) { @writer.replace_draft(course_id: course.id, tree:) }
            end
            raise ActiveRecord::Rollback
          end
        end
      end

      test "l'exception NotDraft porte le nom que le moteur d'import reconnaît" do
        assert_equal Ports::Catalog::ContentTreeWriterPort::NOT_DRAFT, ContentTreeWriter::NotDraft.name.split("::").last
        assert_operator ContentTreeWriter::NotDraft, :<, ActiveRecord::CheckViolation
      end

      test "replace_draft rend unique le slug d'une notion pris par une autre leçon" do
        @writer.write(author_id: @author.id, at: @at, courses: [ v3_course("racines"), v3_course("autre", notion_slug: "pris") ])
        course = Orm::Course.find_by!(slug: "racines")

        @writer.replace_draft(course_id: course.id, tree: v3_course("racines", existing_id: course.id, notion_slug: "pris"))

        assert_equal [ "pris-2", "pris-b-2" ], course.essentials.order(:position).pluck(:slug)
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
