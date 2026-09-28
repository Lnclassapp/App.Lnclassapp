# 🌐 DELIVERY · Identity::PendingAccountsController
# Rôle : écran de sortie d'un compte sans accueil (élève sans classe, direction sans établissement, enseignant sans école ou en attente) ; ne redirige jamais
# ADR  : 0030, 0040, 0063, 0066 · UDR : 0050, 0052
module Identity
  class PendingAccountsController < AuthenticatedController
    skip_before_action :hold_pending_teacher

    # UDR-0052 §3.9, premier cas applicable : :school_admin_without_school, :teacher (demande en attente ou refusée),
    # :teacher_without_school (retiré, ou demande approuvée puis retiré), :student, puis :other. Le retour par code
    # (Identity::SchoolRejoinsController, Lot C) re-rend cette vue avec @case = :teacher_without_school et @rejoin.
    def show
      @join_request = join_request if current_actor.teacher? && current_actor.school_id.nil?
      @case = case_of(current_actor)
    end

    private

    def case_of(actor)
      return :student if actor.student?
      return :other unless actor.school_id.nil? && (actor.teacher? || actor.school_admin?)
      return :school_admin_without_school if actor.school_admin?

      @join_request ? :teacher : :teacher_without_school
    end

    # Une demande approuvée ne retient plus l'enseignant : il a été retiré depuis (ADR-0066 §4.4).
    def join_request
      Queries::School::JoinRequestsQuery.new.status_for(teacher_id: current_actor.user_id)&.then { it unless it.status == "approved" }
    end
  end
end
