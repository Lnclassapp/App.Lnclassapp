# 🌐 DELIVERY · Communication::InboxesController
# Rôle : « Reçues » (enseignant, direction) et « Toutes les annonces » (élève), les annonces lisibles paginées ; l'équipe va à « Mes annonces »
# ADR  : 0078 (§4.3) · UDR : 0071 (§3.7)
module Communication
  class InboxesController < AuthenticatedController
    allow_roles :student, :teacher, :school_admin, :team

    # L'équipe n'est l'audience d'aucune annonce : son onglet d'arrivée est « Mes annonces ».
    def show
      return redirect_to my_announcements_path if current_actor.team?

      reader = Queries::Communication::ReadableMessages.new.reader_for(actor: current_actor)
      @page = Queries::Communication::InboxQuery.new.page(reader:, now: Time.current, page: params[:page])
    end
  end
end
