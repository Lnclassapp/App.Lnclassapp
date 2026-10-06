# 🌐 DELIVERY · Classroom::AssignmentFollowUpsController
# Rôle : suivi d'un exercice assigné (UDR-0062 §3.5) : comptes et rendus en retard nommés, pour l'enseignant de la classe et l'équipe
# ADR  : 0026, 0072 · UDR : 0062 · FollowAssignmentPolicy avant toute lecture : élève, autre enseignant, direction → 403
module Classroom
  class AssignmentFollowUpsController < AuthenticatedController
    allow_roles :teacher, :team

    def show
      @classroom = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:classroom_public_id])
      return render_not_found if @classroom.nil?

      render_result Policies::Classroom::FollowAssignmentPolicy.new.call(actor: current_actor, classroom: @classroom),
                    success: ->(_) { load_follow_up }
    end

    private

    # Archivée, d'une autre classe ou inconnue : 404 (ADR-0072 §4.4).
    def load_follow_up
      @follow_up = Queries::Classroom::AssignmentFollowUpQuery.new.call(classroom_public_id: @classroom.public_id,
                                                                        public_id: params[:public_id])
      render_not_found if @follow_up.nil?
    end
  end
end
