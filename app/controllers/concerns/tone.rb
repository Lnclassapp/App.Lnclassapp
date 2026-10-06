# 🌐 DELIVERY · Tone — le ton d'un message rendu par un contrôleur (toast, notice) : l'élève est tutoyé
# Rôle : tone_t(".clé") rend « clé_student » pour un élève s'il existe, sinon « clé » ; contrôleurs connectés seulement
# UDR  : 0041 (amendement du 2026-10-06), 0063
module Tone
  extend ActiveSupport::Concern

  private

  def tone_t(key, **)
    return t(key, **) unless current_actor.student?

    t("#{key}_student", **, default: "").presence || t(key, **)
  end
end
