# 🌐 UI · Assessment::StatHelper — libellé d'une case de statistique (<dt>), avec ou sans infobulle
# Rôle : les libellés d'une même grille restent sur une ligne commune : l'icône ⓘ (cible de 48 px) n'ajoute pas de hauteur
# ADR  : 0054 · UDR : 0021, 0054 (§3.4), 0057 · grilles « Ta progression » de l'exercice et Note / Maîtrise du résultat
module Assessment
  module StatHelper
    # Ligne de 16 px : texte et icône alignés en haut ; ouverte au toucher, l'infobulle pousse sa seule case.
    LABEL = "flex items-start gap-0.5 text-xs font-medium text-mute".freeze

    # L'infobulle dans la ligne du libellé : sa cible tactile de 48 px déborde de 16 px en haut et en bas, sans grandir la ligne.
    def stat_info_tip(text, label:)
      tag.span(ui_info_tip(text, label:), class: "-my-4 -ms-3 flex")
    end
  end
end
