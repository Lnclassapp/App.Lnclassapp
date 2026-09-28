# 🌐 DELIVERY · Identity::PendingAccountsController
# Rôle : écran de sortie d'un compte sans accueil (élève sans classe, enseignant sans école ou en attente) ; ne redirige jamais
# ADR  : 0030, 0040, 0063 · UDR : 0050
module Identity
  class PendingAccountsController < AuthenticatedController
    CASES = %i[student teacher].freeze

    skip_before_action :hold_pending_teacher

    def show
      @case = CASES.include?(current_actor.role) ? current_actor.role : :other
      @join_request = Queries::School::JoinRequestsQuery.new.status_for(teacher_id: current_actor.user_id) if @case == :teacher
    end
  end
end
