# 🌐 DELIVERY · Classroom::AssignmentsController
# Rôle : assigner et retirer une ressource d'une classe ; chaque réponse est un Turbo Stream qui remplace la bascule
# ADR  : 0026, 0028, 0048 · UDR : 0006, 0028
module Classroom
  class AssignmentsController < AuthenticatedController
    allow_roles :teacher, :team

    # Refus rendus en place (422), avec leur raison : déjà assigné, déjà retiré, type inconnu.
    REFUSALS = %i[conflict invalid].freeze

    def create
      dto = Dtos::Classroom::AssignmentInput.new(
        params.expect(assignment: %i[assignable_type assignable_key]).merge(classroom_public_id: params[:classroom_public_id])
      )
      respond_with_toggle assign_resource.call(actor: current_actor, dto:)
    end

    # La bascule envoie sa classe : l'assignation doit lui appartenir.
    def archive
      respond_with_toggle archive_assignment.call(actor: current_actor, classroom_public_id: params[:classroom_public_id],
                                                  public_id: params[:public_id])
    end

    private

    # Toujours un Turbo Stream, jamais un 204 (CL-20) ; sans Turbo, retour à la page d'où le bouton a été cliqué.
    def respond_with_toggle(result)
      return render_refusal(result) if REFUSALS.include?(result.code)

      render_result result, success: ->(outcome) { render_toggle(outcome) }
    end

    def render_toggle(outcome)
      @assignment = outcome.assignment
      @classroom = outcome.classroom
      @message = t(".done", name: @assignment.assignable.name, classroom: @classroom.name)
      respond_to do |format|
        format.turbo_stream { render action_name }
        format.html { redirect_back_or_to classroom_path(@classroom.public_id), notice: @message, status: :see_other }
      end
    end

    def render_refusal(result)
      @refusal = t("classroom.assignments.refusals.#{result.errors.fetch(:base, [ result.code ]).first}")
      respond_to do |format|
        format.turbo_stream { render action_name, status: :unprocessable_entity }
        format.html { redirect_back_or_to classroom_path(params[:classroom_public_id]), alert: @refusal, status: :see_other }
      end
    end

    def assign_resource = UseCases::Classroom::AssignResource.new(**dependencies)
    def archive_assignment = UseCases::Classroom::ArchiveAssignment.new(**dependencies)

    def dependencies
      { classrooms: Repositories::Classroom::ClassroomRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
        policy: Policies::Classroom::AssignPolicy.new, clock: Time.zone }
    end
  end
end
