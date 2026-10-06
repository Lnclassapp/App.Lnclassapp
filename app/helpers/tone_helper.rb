# 🌐 UI · ToneHelper — le ton d'un texte partagé par tous les rôles : l'élève est tutoyé, les autres rôles vouvoyés
# Rôle : tone_t(".clé") rend « clé_student » pour un élève connecté s'il existe, sinon « clé » (charte §1, UDR-0063)
# UDR  : 0041 (amendement du 2026-10-06), 0063, 0064
module ToneHelper
  # Les clés relatives se résolvent comme t(".clé") : dans la vue qui appelle.
  def tone_t(key, **)
    return t(key, **) unless current_actor&.student?

    t("#{key}_student", **, default: "").presence || t(key, **)
  end
end
