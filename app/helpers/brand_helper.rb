# 🌐 UI · BrandHelper — le logo Lnclass à afficher : le baobab sur bleu, ou celui des enseignants
# Rôle : dans la coque « Lnclass Teacher » et sur les pages des enseignants, le baobab au bras levé sur orange (porteur, 2026-10-08)
# ADR  : 0085 · UDR : 0081
module BrandHelper
  LOGOS = { default: "logo/lnclass.jpeg", teacher: "logo/lnclass-teacher.jpeg" }.freeze

  # teacher: true pour une page propre aux enseignants (l'inscription, par exemple), même vue dans un navigateur.
  def brand_logo(teacher: false)
    LOGOS.fetch(teacher || lnclass_app == :android_teacher ? :teacher : :default)
  end
end
