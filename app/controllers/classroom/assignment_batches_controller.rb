# 🌐 DELIVERY · Classroom::AssignmentBatchesController
# Rôle : l'enseignant envoie à une classe les exercices qu'il a choisis dans les feuilles (un devoir composé) ; Turbo Stream qui remplace
#        le bandeau d'envoi et les bascules des exercices assignés ; un refus se rend en place (toast), la sélection reste au navigateur
# ADR  : 0048, 0072, sujets-de-devoir (ajout du 2026-10-30) · UDR : feuilles-prepare-interros-et-devoirs §3 (Devoir composé par l'enseignant)
module Classroom
  class AssignmentBatchesController < AuthenticatedController
    allow_roles :teacher

    # Refus rendus en place (422) avec leur raison ; les droits et la classe suivent les pages d'erreur ordinaires.
    REFUSALS = %i[invalid conflict].freeze

    def create
      result = assign_exercise_batch.call(actor: current_actor, classroom_public_id: params[:classroom_public_id],
                                          exercise_public_ids: submitted_ids)
      return render_refusal(result) if REFUSALS.include?(result.code)

      render_result result, success: ->(sent) { render_sent(sent) }
    end

    private

    # Ce que le navigateur envoie, tel quel : le use case en fait le tri (texte seulement, doublons, bornes).
    def submitted_ids = params[:exercise_public_ids].then { it.is_a?(Array) ? it : nil }

    def render_sent(sent)
      @classroom = sent.classroom
      @created = sent.created
      @skipped_titles = sent.skipped.map(&:name)
      @message = t("classroom.assignments.batch.done", classroom: @classroom.name, count: @created.size)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to back_location, notice: html_notice, status: :see_other }
      end
    end

    # Sans Turbo, un seul message : l'envoi, puis les exercices écartés.
    def html_notice
      [ (@message if @created.any?),
        (t("classroom.assignments.batch.already_assigned", titles: @skipped_titles.join(", ")) if @skipped_titles.any?) ].compact.join(" ")
    end

    def render_refusal(result)
      @refusal = refusal_message(result)
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html { redirect_to back_location, alert: @refusal, status: :see_other }
      end
    end

    def refusal_message(result)
      return t("classroom.assignments.batch.needs_session_days") if result.errors.key?(:weekdays)

      reason = result.errors.fetch(:base).first
      reason == :other_level ? t("classroom.assignments.refusals.other_level") : t("classroom.assignments.batch.#{reason}")
    end

    def back_location = url_from(request.referer) || classroom_path(params[:classroom_public_id])

    def assign_exercise_batch
      UseCases::Classroom::AssignExerciseBatch.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
        session_days: Repositories::Classroom::SessionDaysRepository.new, policy: Policies::Classroom::AssignPolicy.new,
        session_days_policy: Policies::Classroom::SetSessionDaysPolicy.new, clock: Time.zone
      )
    end
  end
end
