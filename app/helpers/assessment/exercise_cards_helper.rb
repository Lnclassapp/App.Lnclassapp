# 🌐 UI · Assessment::ExerciseCardsHelper — traduit chaque ligne de lecture d'un exercice en une même `Card`
# Rôle : seul endroit où un exercice listé devient titre, matière, type, état et verbe d'action ; le partial assessment/exercises/_card la rend
# ADR  : 0072, 0113 · UDR : XXXX-exercices-et-questions-en-cartes (§3.1) · le domaine ne connaît pas la carte : elle ne lit que des lignes de queries
module Assessment
  module ExerciseCardsHelper
    # dom_id : l'id du <li> (ou nil) · href : la destination (nil : carte sans lien ni action) · material_name : nil si la page le dit déjà
    # · type_label : « Fixation » / « Évaluation » (ou nil) · meta : texte court facultatif · status : HTML déjà rendu (ou nil)
    # · action : le verbe (ou nil) · progress : [faits, attendus] pour l'enseignant (ou nil).
    Card = Data.define(:dom_id, :href, :title, :material_name, :material_slug, :type_label, :meta, :status, :action, :progress)

    CARD_SCOPE = "assessment.exercises.card".freeze

    # « Ma classe », à faire : StudentHomeQuery::ExerciseRow.
    def exercise_card_for_assigned(row)
      Card.new(dom_id: "exercise-#{row.public_id}", href: exercise_path(row.public_id), title: row.title,
               material_name: row.material_name, material_slug: row.material_slug, type_label: exercise_type_label(row.exercise_type),
               meta: nil, status: due_badge(row.due_on), action: card_t(row.started_session_public_id ? :resume : :start),
               progress: nil)
    end

    # « Ma classe », traités : StudentClassroomQuery::TreatedRow. La couleur de la note ne porte jamais seule le sens : le texte reste.
    def exercise_card_for_treated(row)
      status = safe_join([ grade_tag(row.best_score_percent),
                           tag.span(card_t(:separator) + mastery_label(row.best_score_percent), class: "text-sm text-mute") ])
      Card.new(dom_id: nil, href: exercise_session_result_path(row.last_session_public_id), title: row.title,
               material_name: row.material_name, material_slug: row.material_slug, type_label: exercise_type_label(row.exercise_type),
               meta: nil, status:, action: card_t(:view_copy), progress: nil)
    end

    # Page d'une leçon : PrepareInterrosQuery::ExerciseRow. La matière est dite dans l'en-tête de la page : pas de material_name.
    # student : l'élève lit son état ; team : l'équipe lit le statut éditorial ; l'enseignant n'a ni l'un ni l'autre.
    def exercise_card_for_lesson(row, material_slug:, team:, student:)
      state = row.student_state
      Card.new(dom_id: "exercise-#{row.public_id}", href: exercise_path(row.public_id), title: row.title, material_name: nil,
               material_slug:, type_label: exercise_type_label(row.exercise_type), meta: card_t(:questions, count: row.questions_count),
               status: (team ? content_status_badge(row.status) : lesson_state_badge(state)),
               action: card_t(lesson_action(state, student:)), progress: nil)
    end

    # Classe de l'enseignant : ClassroomOverviewQuery::AssignmentRow. Sans droit de suivi (counts nil) : ni lien ni action.
    def exercise_card_for_assignment(row, classroom_public_id:)
      counts = row.counts
      Card.new(dom_id: "assignment_#{row.public_id}", href: (classroom_assignment_path(classroom_public_id, row.public_id) if counts),
               title: row.exercise_title, material_name: row.material_name, material_slug: row.material_slug,
               type_label: exercise_type_label(row.exercise_type), meta: nil, status: assignment_status(row),
               action: (card_t(:follow) if counts), progress: (counts && [ counts.done, counts.done + counts.pending ]))
    end

    private

    def card_t(key, **) = t("#{CARD_SCOPE}.#{key}", **)

    # Un type manquant lève : « exercise_types. » se résoudrait au groupe entier et afficherait un Hash.
    def exercise_type_label(type)
      raise ArgumentError, "exercise_type manquant" if type.blank?

      t("assessment.exercises.show.exercise_types.#{type}")
    end

    def grade_tag(score) = tag.span(grade_label(score), class: class_names("font-display font-medium tabular-nums", grade_class(score)))

    def lesson_state_badge(state)
      case state&.kind
      when :to_review then ui_badge(card_t(:to_review), tone: :warning, icon: "arrow-path")
      when :due then due_badge(state.due_on)
      when :score then grade_tag(state.score_percent)
      end
    end

    # Revoir (lacune en attente) ; Refaire sous 10/20 ; Commencer sinon ; l'enseignant et l'équipe ouvrent l'exercice.
    def lesson_action(state, student:)
      return :open unless student
      return :review if state&.kind == :to_review
      return :redo if state&.kind == :score && !Entities::Assessment::Grading.reaches?(state.score_percent, Entities::Assessment::Grading::PASS_THRESHOLD)

      :start
    end

    def assignment_status(row)
      pending = row.counts&.pending.to_i
      late = row.due_on && row.due_on < Time.zone.today
      badge = if pending.zero? then nil
      elsif late then ui_badge(t("assessment.comprehension.progress.late", count: pending), tone: :warning, dot: true)
      else ui_badge(card_t(:pending, count: pending))
      end
      tag.div(safe_join([ tag.span(due_for_teacher(row.due_on), class: "text-sm text-mute"), badge ].compact),
              class: "flex flex-wrap items-center gap-x-3 gap-y-1")
    end
  end
end
