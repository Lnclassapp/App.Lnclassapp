# 🌐 DELIVERY · Classroom::AssignmentFollowUpsController
# Rôle : rapport d'un exercice assigné (UDR enseignant §3.8) : comptes, cases par badge (?badge=), questions, élèves (ceux qui ne l'ont pas fait compris)
# ADR  : 0026, 0072, 0079, 0088 · UDR : 0062, 0072, enseignant §3.8 · FollowAssignmentPolicy avant toute lecture : élève, autre enseignant, direction → 403
module Classroom
  class AssignmentFollowUpsController < AuthenticatedController
    allow_roles :teacher, :team

    def show
      @classroom = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:classroom_public_id])
      # vie-de-la-classe, Lot C (ADR-0088, Q8) : une classe archivée n'a plus de page, quel que soit le rôle ; elle se restaure.
      return render_not_found if @classroom.nil? || @classroom.status == "archived"

      render_result Policies::Classroom::FollowAssignmentPolicy.new.call(actor: current_actor, classroom: @classroom),
                    success: ->(_) { load_follow_up }
    end

    private

    # Archivée, d'une autre classe ou inconnue : 404 (ADR-0072 §4.4).
    def load_follow_up
      @follow_up = Queries::Classroom::AssignmentFollowUpQuery.new.call(classroom_public_id: @classroom.public_id,
                                                                        public_id: params[:public_id])
      return render_not_found if @follow_up.nil?

      @comprehension = Queries::Assessment::ComprehensionDetailQuery.new.call(classroom_public_id: @classroom.public_id,
                                                                              assignment_public_id: @follow_up.public_id,
                                                                              badge: requested_badge)
    end

    # Liste blanche : un badge inconnu est ignoré (tous les élèves), jamais de to_sym sur une entrée libre.
    def requested_badge
      Queries::Assessment::ComprehensionDetailQuery::BADGES.find { |badge| badge.name == params[:badge] }
    end
  end
end
