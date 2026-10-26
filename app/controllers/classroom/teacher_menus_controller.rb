# 🌐 DELIVERY · Classroom::TeacherMenusController
# Rôle : « Mon compte » de l'enseignant rendu comme une page (/teachers/menu) : ouvert en modale par l'app, repli sans JavaScript du site ; les « N sur 3 » sont lus par le panneau
# ADR  : 0086 · UDR : 0082 §3.2, écrans enseignant sans répétition §3.4 · enseignant seulement ; le contenu est celui du panneau de l'en-tête (shared/navigation/_account_panel)
module Classroom
  class TeacherMenusController < AuthenticatedController
    allow_roles :teacher

    def show; end
  end
end
