# 🌐 DELIVERY · Identity::PendingAccountsController
# Rôle : écran de sortie d'un compte sans accueil (élève sans classe, enseignant sans école ou en attente) ; ne redirige jamais
# ADR  : 0030, 0036, 0040, 0063, 0071, 0083, XXXX-recherche-etablissement · UDR : 0050, 0056, 0079 · l'élève qui a quitté sa classe y trouve son historique (lot R)
module Identity
  class PendingAccountsController < AuthenticatedController
    CASES = %i[student teacher].freeze
    PENDING = "pending".freeze

    include SchoolSearchField

    skip_before_action :hold_pending_teacher

    def show
      @case = CASES.include?(current_actor.role) ? current_actor.role : :other
      @archived = Queries::Classroom::StudentArchiveQuery.new.any?(student_id: current_actor.user_id) if @case == :student
      return unless @case == :teacher

      @join_request = Queries::School::JoinRequestsQuery.new.status_for(teacher_id: current_actor.user_id)
      # Sans établissement ni demande en attente : l'établissement cherché (ADR-0083 §4.3, ADR-XXXX-recherche-etablissement).
      # Sans JavaScript, la recherche revient ici en GET (formulaire school-join-search, school_q).
      return unless current_actor.school_id.nil? && @join_request&.status != PENDING

      @school_join = Dtos::School::SchoolJoinInput.new
    end
  end
end
