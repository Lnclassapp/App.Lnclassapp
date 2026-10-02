# 🌐 DELIVERY · Communication::HelpController — « Questions fréquentes » (/aide), page publique et statique
# Rôle : rend la FAQ, lisible sans connexion (« PIN oublié ») ; l'ordre des questions vit ici, leurs textes en locale
# UDR  : 0061 (FAQ, construite directement à la demande du porteur, 2026-10-02), 0057, 0060, 0062 §4 (« En retard »)
module Communication
  class HelpController < ApplicationController
    allow_unauthenticated_access

    # Ordre d'affichage : d'abord ce qui bloque l'élève (PIN, classe), puis ce que dit sa liste « À faire » (échéance,
    # UDR-0062), puis ce qui l'aide à comprendre ses résultats.
    QUESTIONS = %i[pin join change_classroom late grade badges mastery gaps retry profile].freeze

    def show; end
  end
end
