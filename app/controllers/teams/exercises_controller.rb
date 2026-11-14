# 🌐 DELIVERY · Teams::ExercisesController
# Rôle : l'équipe publie ou archive un exercice et en corrige le texte en modale (bonne réponse comprise) ; ni création ni changement de structure à l'écran (CA-29)
# ADR  : 0026, 0028, 0035, 0036, 0054, 0091, 0105, 0113 (§4.6, amendement du 2026-11-14) · UDR : 0006, 0017, 0042, 0087, 0129
module Teams
  class ExercisesController < BaseController
    def publish = change_status(publish_exercise)
    def archive = change_status(archive_exercise)

    # edition-texte-lecon : le texte enregistré de l'exercice, dans la modale. La policy répond avant toute lecture.
    def edit_text
      allowed = manage_content.call(actor: current_actor)
      return render_result(allowed, success: nil) if allowed.failure?

      @exercise = exercises.find_by_public_id(public_id: params[:public_id])
      return render_not_found if @exercise.nil?

      @text = text_from_exercise(@exercise)
      @errors = {}
    end

    # Succès : toast, modale refermée, page re-demandée (morphing). Refus de saisie : 422, la modale garde la saisie.
    def update_text
      @text = text_from_params
      result = correct_exercise_text.call(actor: current_actor, public_id: params[:public_id], text: @text)
      return refuse_text(result) if result.code == :invalid

      render_result result, success: lambda { |exercise|
        @exercise = exercise
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_back_or_to courses_path, notice: t(".updated", title: exercise.title), status: :see_other }
        end
      }
    end

    private

    def refuse_text(result)
      @exercise = exercises.find_by_public_id(public_id: params[:public_id])
      @errors = result.errors
      render :edit_text, status: :unprocessable_entity
    end

    def text_from_exercise(exercise)
      text = UseCases::Assessment::CorrectExerciseText
      questions = exercise.questions.map do |question|
        answers = question.answers.map { text::AnswerText.new(id: it.id, content: it.content, match_content: it.match_content, correct: it.correct) }
        text::QuestionText.new(id: question.id, content: question.content, explanation: question.explanation.to_s, hint: question.hint.to_s, answers:)
      end
      text::ExerciseText.new(title: exercise.title, statement: exercise.statement.to_s, hint: exercise.hint.to_s, questions:)
    end

    # Les identifiants viennent du formulaire : le use case refuse tout écart avec la structure enregistrée (structure_changed).
    # La bonne réponse : un bouton radio « key » (une seule juste), un par case « keys[case] » (liste), ou une case à cocher par proposition.
    def text_from_params
      text = UseCases::Assessment::CorrectExerciseText
      input = params.fetch(:exercise_text, {})
      questions = given_hash(input[:questions]).map do |question_id, question|
        keys = [ question[:key], *scalars(question[:keys]) ].compact.map(&:to_s)
        answers = given_hash(question[:answers]).map do |answer_id, answer|
          text::AnswerText.new(id: id_of(answer_id), content: answer[:content].to_s, match_content: answer[:match_content]&.to_s,
                               correct: keys.include?(answer_id.to_s) || answer[:correct] == "1")
        end
        text::QuestionText.new(id: id_of(question_id), content: question[:content].to_s, explanation: question[:explanation].to_s,
                               hint: question[:hint].to_s, answers:)
      end
      text::ExerciseText.new(title: input[:title].to_s, statement: input[:statement].to_s, hint: input[:hint].to_s, questions:)
    end

    # Lecture champ par champ, sans affectation de masse : les entrées d'un hash du formulaire qui sont elles-mêmes des hash.
    # Une entrée forgée (texte à la place d'une question) est écartée : le use case refuse alors la structure (422).
    def given_hash(value)
      value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
      value.is_a?(Hash) ? value.to_a.select { |_, nested| nested.is_a?(Hash) } : []
    end

    # Les bonnes réponses d'une liste, une par case : seules les valeurs texte comptent.
    def scalars(value)
      value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
      value.is_a?(Hash) ? value.values.grep(String) : []
    end

    def id_of(value) = Integer(value.to_s, exception: false)

    def correct_exercise_text = UseCases::Assessment::CorrectExerciseText.new(**transition_dependencies)

    def change_status(use_case)
      result = use_case.call(actor: current_actor, public_id: params[:public_id])
      return refuse_transition(result) if result.code == :conflict

      render_result result, success: lambda { |exercise|
        @exercise = exercise
        respond_to do |format|
          format.turbo_stream { render :transition }
          format.html do
            redirect_to exercise_path(exercise.public_id), status: :see_other,
                                                           notice: t("teams.exercises.transition.#{exercise.status}", title: exercise.title)
          end
        end
      }
    end

    # Refus d'une transition (sans question, fiche non publiée, retour interdit, image manquante) : toast d'erreur qui en
    # dit la raison, et le numéro de la question en cause (ADR-0105 §4.4).
    def refuse_transition(result)
      @refusal = t("teams.exercises.transition.refusals.#{result.errors.fetch(:base).first}", number: result.errors[:number]&.first)
      respond_to do |format|
        format.turbo_stream { render :transition, status: :unprocessable_entity }
        format.html { redirect_to exercise_path(params[:public_id]), alert: @refusal, status: :see_other }
      end
    end

    def exercises = @exercises ||= Repositories::Assessment::ExerciseRepository.new

    def publish_exercise = UseCases::Assessment::PublishExercise.new(**transition_dependencies)
    def archive_exercise = UseCases::Assessment::ArchiveExercise.new(**transition_dependencies)

    def transition_dependencies
      { exercises:, audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy: manage_content, clock: Time.zone }
    end

    def manage_content = Policies::Catalog::ManageContentPolicy.new
  end
end
