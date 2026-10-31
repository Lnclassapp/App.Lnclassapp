# 🔌 INFRA · Queries::Catalog::PrepareSheetsQuery
# Rôle : les feuilles « Prépare interros » (une par notion, puis « Toute la leçon ») et « Prépare devoirs » (une par sujet) de la leçon : exercices, questions, indice, figure, dernière copie terminée de l'élève, classes de l'enseignant
# ADR  : XXXX-sujets-de-devoir-et-verification-sur-la-feuille, 0113 · UDR : XXXX-feuilles-prepare-interros-et-devoirs §3 (remplace PrepareInterrosQuery, UDR-0139 §3.4)
module Queries
  module Catalog
    class PrepareSheetsQuery
      # interros, devoirs : [Sheet] dans l'ordre de la page ; targets : Queries::Classroom::CatalogAssignmentTargetsQuery::Targets pour un
      # enseignant, nil pour tout autre rôle ; bare : les notions lisibles par ce rôle qui n'ont aucun exercice visible (leur ancre
      # « notion-<slug> » reste la cible des liens) ; course_name, material_name, level_name : le cartouche de chaque feuille.
      Prepare = Data.define(:interros, :devoirs, :targets, :bare, :course_name, :material_name, :level_name) do
        def sheets = interros + devoirs
        def exercise(public_id) = sheets.flat_map(&:exercises).find { it.public_id == public_id }
        def sheet_of(public_id) = sheets.find { |sheet| sheet.exercises.any? { it.public_id == public_id } }
      end
      Bare = Data.define(:essential_slug, :title)
      # kind : :notion · :lesson_wide · :subject ; dom_id : l'ancre de la feuille (« notion-<slug> », « toute-la-lecon », « sujet-<n> ») ;
      # note : « À retenir » (notion) ou « Notions mobilisées » (sujet), nil si vide ; number / total : « Notion n / N », « Sujet n / N ».
      Sheet = Data.define(:kind, :dom_id, :title, :note, :number, :total, :exercises) do
        # Le compte de « x / n exercices réussis » : l'id du repère est `sheet-progress-<dom_id>`.
        def passed = exercises.count { it.copy&.passed }
        def progress_id = "sheet-progress-#{dom_id}"
      end
      # copy : la dernière copie terminée de l'élève (Copy), nil sans copie ou hors élève ; questions : [Question] ;
      # due : un élève qui doit encore rendre cet exercice à son enseignant (CA-17) : la feuille ne le vérifie pas ;
      # status : le statut éditorial ("draft" | "published"), que seule l'équipe lit sur la feuille.
      SheetExercise = Data.define(:public_id, :number, :title, :statement, :statement_blocks, :figure, :hint, :questions, :copy, :due, :status) do
        def initialize(due: false, status: nil, **) = super
      end
      # passed : toutes les questions justes ; la note de la copie est celle de sa page de résultat (sur 20).
      Copy = Data.define(:session_public_id, :passed)
      # kind : :mcq · :true_false · :fill_in · :calculation · :other (play : la question de la session de lecture, pour son partiel) ;
      # multiple : un QCM à 2 ou 3 réponses justes ; choices : [Choice] d'un QCM ou d'un vrai ou faux ; image : l'image au-dessus de l'énoncé, nil sinon. La correction (response,
      # verdict :correct | :wrong | :empty) n'est lue que pour un exercice corrigé : nil avant.
      Question = Data.define(:id, :number, :kind, :content, :unit, :multiple, :choices, :play, :image, :response, :verdict)
      # index : le rang dans l'ordre de la feuille (celui que la feuille poste) ; picked : l'élève l'a coché dans sa copie corrigée.
      Choice = Data.define(:index, :letter, :content, :picked)

      # Le mélange des étapes (ordre, relier) n'a pas de session avant la vérification : la feuille les montre dans celui de cette graine.
      SHEET_SEED = 0
      KIND_OF = { "true_false" => :true_false, "single_choice" => :mcq, "multiple_correct_2" => :mcq, "multiple_correct_3" => :mcq,
                  "fill_blank" => :fill_in, "numeric" => :calculation }.freeze
      EXERCISE_COLUMNS = %i[id public_id title status essential_id subject_id statement statement_blocks figure_key hint].freeze
      EMPTY = Prepare.new(interros: [], devoirs: [], targets: nil, bare: [], course_name: nil, material_name: nil, level_name: nil)

      # → Prepare. Un cours inconnu rend des listes vides ; la lecture d'un brouillon est l'affaire de ReadPublishedPolicy, en amont.
      def call(course_slug:, actor:)
        course = Orm::Course.joins(:material, :level).where(slug: course_slug)
                            .pick("courses.id", "courses.name", "courses.figures", "materials.name", "levels.name")
        return EMPTY if course.nil?

        course_id, course_name, figures, material_name, level_name = course
        team = actor&.team? || false
        rows = exercises(course_id, team)
        built = build_exercises(rows, figures, actor)
        Prepare.new(interros: interros(course_id, rows, built), devoirs: devoirs(course_id, rows, built),
                    targets: targets(course_slug, actor, rows), bare: bare(course_id, rows, team), course_name:, material_name:, level_name:)
      end

      private

      def exercises(course_id, team)
        # CA-30 : un exercice archivé ne figure ici pour personne ; l'équipe garde les brouillons.
        scope = Orm::Exercise.where(course_id:, archived_at: nil).where.not(status: "archived").order(:position, :id)
        # ADR-0028 : l'élève lit un exercice publié dont la notion est publiée (celui de toute la leçon ou d'un sujet n'en a pas).
        scope = scope.left_joins(:essential).where(status: "published")
                     .where("essentials.id IS NULL OR essentials.status = 'published'") unless team
        scope.pluck(*EXERCISE_COLUMNS.map { "exercises.#{it}" })
      end

      # { id => SheetExercise sans numéro } : le numéro dit le rang dans la feuille, posé quand la feuille est connue.
      def build_exercises(rows, figures, actor)
        ids = rows.map(&:first)
        questions = questions(ids)
        copies = actor&.student? ? copies(ids, actor.user_id, questions) : {}
        due = actor&.student? ? due_public_ids(rows, actor.user_id) : Set.new
        rows.to_h do |id, public_id, title, status, _essential_id, _subject_id, statement, statement_blocks, figure_key, hint|
          copy, corrected = copies[id]
          [ id, SheetExercise.new(public_id:, number: 0, title:, statement:, statement_blocks:,
                                  figure: Queries::Assessment::SessionPlayQuery.figure_for(figures, figure_key),
                                  hint: hint.presence, questions: question_list(questions.fetch(id, []), corrected), copy:,
                                  due: due.include?(public_id), status:) ]
        end
      end

      # CA-17 : les exercices assignés à l'élève et pas encore rendus (une lecture de plus).
      def due_public_ids(rows, student_id)
        Repositories::Assessment::PendingAssignmentRepository.new.pending_exercise_public_ids(student_id:, exercise_public_ids: rows.map { it[1] })
      end

      def interros(course_id, rows, built)
        by_essential = rows.group_by { it[4] }
        notions = Orm::Essential.where(course_id:, id: by_essential.keys.compact).order(:position, :id)
                                .pluck(:id, :slug, :name, Arel.sql("essentials.sheet->>'remember'"))
        wide = by_essential.fetch(nil, []).reject { it[5] }
        total = notions.size + (wide.empty? ? 0 : 1)
        sheets = notions.each_with_index.map do |(id, slug, name, remember), index|
          sheet(:notion, "notion-#{slug}", name, remember, index + 1, total, by_essential[id], built)
        end
        sheets << sheet(:lesson_wide, "toute-la-lecon", nil, nil, total, total, wide, built) unless wide.empty?
        sheets
      end

      def devoirs(course_id, rows, built)
        by_subject = rows.group_by { it[5] }
        # Le sujet doit être de cette leçon : un exercice rattaché au sujet d'une autre leçon ne s'affiche jamais.
        subjects = Orm::Subject.where(id: by_subject.keys.compact, course_id:).order(:position, :id).pluck(:id, :position, :title, :notions)
        subjects.each_with_index.map do |(id, position, title, notions), index|
          sheet(:subject, "sujet-#{position}", title, notions, index + 1, subjects.size, by_subject[id], built)
        end
      end

      def sheet(kind, dom_id, title, note, number, total, rows, built)
        exercises = rows.each_with_index.map { |row, index| built.fetch(row.first).with(number: index + 1) }
        Sheet.new(kind:, dom_id:, title:, note: note.presence, number:, total:, exercises:)
      end

      # ADR-0028 : l'élève lit les notions publiées ; l'équipe, toutes.
      def bare(course_id, rows, team)
        scope = Orm::Essential.where(course_id:).where.not(id: rows.filter_map { it[4] })
        scope = scope.where(status: "published") unless team
        scope.order(:position, :id).pluck(:slug, :name).map { |slug, name| Bare.new(essential_slug: slug, title: name) }
      end

      def targets(course_slug, actor, rows)
        return unless actor&.teacher?

        Queries::Classroom::CatalogAssignmentTargetsQuery.new.call(
          teacher_id: actor.user_id, school_id: actor.school_id, course_slug:,
          exercise_public_ids: rows.select { it[3] == "published" }.map { it[1] }
        )
      end

      # { exercise_id => [Row] } : questions, propositions et images en trois lectures pour toute la leçon (ni N+1, ni une par exercice).
      QuestionRow = Data.define(:id, :type, :content, :unit, :starter, :answers, :image)
      AnswerRow = Data.define(:id, :content, :match_content, :correct)

      def questions(exercise_ids)
        rows = Orm::Question.where(exercise_id: exercise_ids).order(:exercise_id, :position, :id)
                            .pluck(:exercise_id, :id, :question_type, :content, :unit, :starter)
        ids = rows.map { it[1] }
        answers = Orm::Answer.where(question_id: ids).order(:question_id, :position, :id)
                             .pluck(:question_id, :id, :content, :match_content, :correct).group_by(&:first)
        images = Orm::QuestionImage.where(question_id: ids).pluck(:question_id, :public_id, :alt, :width, :height)
                                   .to_h { |question_id, *image| [ question_id, Queries::Assessment::SessionPlayQuery::Image.new(*image) ] }
        rows.group_by(&:first).transform_values do |list|
          list.map do |_, id, type, content, unit, starter|
            QuestionRow.new(id:, type:, content:, unit:, starter:, image: images[id],
                            answers: answers.fetch(id, []).map { AnswerRow.new(*it.drop(1)) })
          end
        end
      end

      # { exercise_id => [Copy, { question_id => [correct, selected_answer_ids, response_text, unanswered] }] } : la dernière copie
      # terminée de l'élève par exercice, avec ses tentatives.
      def copies(exercise_ids, student_id, questions)
        sessions = Orm::ExerciseSession.where(student_id:, exercise_id: exercise_ids, status: "completed")
                                       .order(:exercise_id, completed_at: :desc, id: :desc)
                                       .pluck(Arel.sql("DISTINCT ON (exercise_sessions.exercise_id) exercise_sessions.exercise_id"),
                                              :id, :public_id, :correct_count, :question_count)
        attempts = Orm::QuestionAttempt.where(exercise_session_id: sessions.map { it[1] })
                                       .pluck(:exercise_session_id, :question_id, :correct, :selected_answer_ids, :response_text, :unanswered)
                                       .group_by(&:first)
        sessions.to_h do |exercise_id, id, public_id, correct, count|
          taken = attempts.fetch(id, []).to_h { |_, question_id, *attempt| [ question_id, attempt ] }
          [ exercise_id, [ Copy.new(session_public_id: public_id, passed: correct == count), taken ] ]
        end
      end

      def question_list(rows, taken)
        rows.each_with_index.map { |row, index| question(row, index + 1, taken&.dig(row.id), !taken.nil?) }
      end

      def question(row, number, attempt, corrected)
        kind = KIND_OF.fetch(row.type, :other)
        correct, selected, text, unanswered = attempt
        verdict = (unanswered || (selected.blank? && text.nil?) ? :empty : (correct ? :correct : :wrong)) if corrected && auto_graded?(row)
        picked = Array(selected)
        Question.new(id: row.id, number:, kind:, content: row.content, unit: row.unit.presence, image: row.image,
                     multiple: Entities::Assessment::Question::EXPECTED.fetch(row.type.to_sym, 1) > 1,
                     choices: (choices(row, picked) if %i[mcq true_false].include?(kind)),
                     play: (play(row, number) if kind == :other),
                     response: (text if corrected), verdict:)
      end

      def auto_graded?(row) = Entities::Assessment::Question.kind_for(row.type)::AUTO_GRADED

      def choices(row, picked)
        row.answers.each_with_index.map do |answer, index|
          Choice.new(index:, letter: ("A".ord + index).chr, content: answer.content, picked: picked.include?(answer.id))
        end
      end

      # La question de la session de lecture, pour le partiel de son type : propositions dans l'ordre des positions (select) ou dans
      # le mélange de la feuille (ordre, relier), sans jamais dire laquelle est juste.
      def play(row, number)
        answers = row.answers
        details = case Entities::Assessment::Question.kind_name_for(row.type)
        when "select" then { answers: answers.each_with_index.map { |answer, index| Queries::Assessment::SessionPlayQuery::Answer.new(id: answer.id, content: answer.content, index:) } }
        when "ordering" then { items: items(row, answers.to_h { [ it.id, it.content ] }) }
        when "matching" then { prompts: answers.map(&:content), items: items(row, answers.to_h { [ it.id, it.match_content ] }) }
        else {}
        end
        Queries::Assessment::SessionPlayQuery::Question.new(id: row.id, number:, content: row.content, question_type: row.type, answers: [],
                                                            image: row.image, unit: row.unit, starter: row.starter, **details)
      end

      def items(row, contents)
        Entities::Assessment::AnswerShuffle.for(session_id: SHEET_SEED, question_id: row.id, ids: contents.keys, avoid: contents.keys)
                                           .each_with_index.map { |id, index| Queries::Assessment::SessionPlayQuery::Item.new(index:, content: contents[id]) }
      end
    end
  end
end
