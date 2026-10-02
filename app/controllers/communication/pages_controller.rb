# 🌐 DELIVERY · Communication::PagesController — pages publiques et statiques : mission, données, CGU, CGV
# Rôle : rend la vue de même nom si la page est dans ONLINE, sinon 404 ; ni table, ni query, ni use case
# UDR  : 0063 (§3.1, §2.4 : une page n'entre dans ONLINE qu'après la validation des juristes), 0061
module Communication
  class PagesController < ApplicationController
    allow_unauthenticated_access

    # Ordre des liens du pied de page, de /aide et de la carte d'aide.
    PAGES = %i[mission privacy terms sales_terms].freeze
    # Liste fermée des pages en ligne. Y ajouter une page est le dernier geste, après validation (lot Z).
    ONLINE = [].freeze

    before_action :require_online_page

    def self.online?(page) = ONLINE.include?(page.to_sym)

    def mission; end
    def privacy; end
    def terms; end
    def sales_terms; end

    private

    # Hors ligne, la page n'existe pas : même 404 qu'une adresse inconnue, aucun indice de son contenu.
    def require_online_page
      raise ActionController::RoutingError, "Page hors ligne : #{action_name}" unless self.class.online?(action_name)
    end
  end
end
