# 🌐 DELIVERY · Classroom::AssignmentsController
# Rôle : assigner et retirer un exercice d'une classe (Turbo Stream qui remplace la bascule) ; la modale des jours de séance
#        (`new`) et son envoi, avec les jours cochés ou « Plus tard »
# ADR  : 0026, 0028, 0048, 0072 · UDR : 0006, 0028, 0062
module Classroom
  class AssignmentsController < AuthenticatedController
    allow_roles :teacher, :team

    # Refus rendus en place (422), avec leur raison : déjà assigné, déjà retiré, type inconnu.
    REFUSALS = %i[conflict invalid].freeze

    # UDR-0062 §3.4 : « Quels jours voyez-vous la <classe> ? », servie dans le frame « modal », lisible sans JavaScript.
    def new
      @classroom = classrooms.find_by_public_id(public_id: params[:classroom_public_id])
      return render_not_found if @classroom.nil?

      render_result days_step_allowed, success: lambda { |_|
        @exercise = exercise(params[:assignable_key])
        return render_not_found if @exercise.nil?

        @form = Dtos::Classroom::AssignmentInput.new(classroom_public_id: @classroom.public_id, assignable_type: "Exercise",
                                                     assignable_key: @exercise.key)
        @return_to = url_from(request.referer)
      }
    end

    def create
      @form = Dtos::Classroom::AssignmentInput.new(
        params.expect(assignment: [ :assignable_type, :assignable_key, { weekdays: [] } ])
              .merge(classroom_public_id: params[:classroom_public_id], later: params[:later].present?)
      )
      result = assign_resource.call(actor: current_actor, dto: @form)
      return render_days_step(result) if result.failure? && result.errors.key?(:weekdays)

      # Les jours viennent d'être connus : les autres « Assigner » de la page n'ouvrent plus la modale (rafraîchissement).
      @days_saved = result.success? && !@form.weekdays.nil?
      respond_with_toggle result
    end

    # La bascule envoie sa classe : l'assignation doit lui appartenir.
    def archive
      respond_with_toggle archive_assignment.call(actor: current_actor, classroom_public_id: params[:classroom_public_id],
                                                  public_id: params[:public_id])
    end

    private

    # La modale est l'étape des jours : réservée à l'enseignant de la classe active (l'équipe n'a pas de jours).
    def days_step_allowed
      [ Policies::Classroom::AssignPolicy.new, Policies::Classroom::SetSessionDaysPolicy.new ]
        .lazy.map { it.call(actor: current_actor, classroom: @classroom) }.find(&:failure?) || Shared::Result.success
    end

    # L'exercice publié, aux parents publiés (ADR-0035) ; nil sinon.
    def exercise(key)
      resolved = Repositories::Classroom::AssignmentRepository.new.resolve_assignable(type: "Exercise", key: key.to_s)
      resolved.assignable if resolved&.readable?
    end

    # « Assigner » sans aucun jour coché : la modale revient en 422, son erreur sur le fieldset (UDR-0062 §3.4).
    def render_days_step(result)
      @classroom = classrooms.find_by_public_id(public_id: params[:classroom_public_id])
      @exercise = exercise(@form.assignable_key)
      return render_not_found if @classroom.nil? || @exercise.nil?

      @return_to = url_from(params[:return_to])
      render_form :new, result
    end

    # Toujours un Turbo Stream, jamais un 204 (CL-20) ; sans Turbo, retour à la page d'où le bouton a été cliqué.
    def respond_with_toggle(result)
      return render_refusal(result) if REFUSALS.include?(result.code)

      render_result result, success: ->(outcome) { render_toggle(outcome) }
    end

    def render_toggle(outcome)
      @assignment = outcome.assignment
      @classroom = outcome.classroom
      @message = toggle_message
      respond_to do |format|
        format.turbo_stream { render action_name }
        format.html { redirect_to back_location, notice: @message, status: :see_other }
      end
    end

    # UDR-0062 §3.4 : le toast d'une assignation datée dit l'échéance, au format long des échéances (`due_long`).
    def toggle_message
      names = { name: @assignment.assignable.name, classroom: @classroom.name }
      return t(".done", **names) unless action_name == "create" && @assignment.due_on

      t(".done_due", **names, date: l(@assignment.due_on, format: :due_long))
    end

    def render_refusal(result)
      @refusal = t("classroom.assignments.refusals.#{result.errors.fetch(:base, [ result.code ]).first}")
      respond_to do |format|
        format.turbo_stream { render action_name, status: :unprocessable_entity }
        format.html { redirect_to back_location, alert: @refusal, status: :see_other }
      end
    end

    # La modale renvoie la page d'où elle a été ouverte (`return_to`, même origine seulement) ; sinon, la page précédente.
    def back_location
      url_from(params[:return_to]) || url_from(request.referer) || classroom_path(params[:classroom_public_id])
    end

    def classrooms = (@classrooms ||= Repositories::Classroom::ClassroomRepository.new)

    def assign_resource
      UseCases::Classroom::AssignResource.new(
        classrooms:, assignments: Repositories::Classroom::AssignmentRepository.new,
        session_days: Repositories::Classroom::SessionDaysRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy: Policies::Classroom::AssignPolicy.new, session_days_policy: Policies::Classroom::SetSessionDaysPolicy.new,
        clock: Time.zone
      )
    end

    def archive_assignment
      UseCases::Classroom::ArchiveAssignment.new(classrooms:, assignments: Repositories::Classroom::AssignmentRepository.new,
                                                 policy: Policies::Classroom::AssignPolicy.new, clock: Time.zone)
    end
  end
end
