# 🌐 DELIVERY · Identity::PendingAccountsController
# Rôle : écran de sortie d'un compte sans accueil (élève sans classe, enseignant sans école) ; ne redirige jamais
# ADR  : 0030, 0040
module Identity
  class PendingAccountsController < AuthenticatedController
    CASES = %i[student teacher].freeze

    def show
      @case = CASES.include?(current_actor.role) ? current_actor.role : :other
    end
  end
end
