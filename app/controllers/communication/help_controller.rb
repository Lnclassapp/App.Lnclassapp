# 🌐 DELIVERY · Communication::HelpController — « Questions fréquentes » (/aide), page statique lisible sans connexion
# Rôle : rend la FAQ ; un compte connecté la lit dans son shell, un visiteur sur le motif des écrans d'entrée
# UDR  : 0061 (FAQ ; amendement du 2026-10-06, shell une fois connecté), 0057, 0060, 0062 §4 (« En retard »)
module Communication
  class HelpController < ApplicationController
    include ShellLayout

    allow_unauthenticated_access
    # UDR-0061, amendement du 2026-10-06 : connecté, l'élève garde sa navigation ; le visiteur (« PIN oublié ») et
    # l'enseignant en attente d'école, qui n'a pas de navigation (ADR-0063), gardent la page d'entrée.
    layout -> { in_shell? ? "shell" : "application" }
    helper_method :in_shell?

    # Ordre d'affichage : d'abord ce qui bloque l'élève (PIN, classe), puis ce que dit sa liste « À faire » (échéance,
    # UDR-0062), puis ce qui l'aide à comprendre ses résultats.
    QUESTIONS = %i[pin join change_classroom late grade badges mastery gaps retry profile].freeze

    def show; end

    private

    def in_shell? = current_actor.present? && !(current_actor.teacher? && current_actor.school_id.nil?)
  end
end
