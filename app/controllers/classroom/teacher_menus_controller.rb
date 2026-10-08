# 🌐 DELIVERY · Classroom::TeacherMenusController
# Rôle : panneau du compte de l'enseignant rendu comme une page (/teachers/menu) : ouvert en modale par l'app, repli sans JavaScript du site
# ADR  : 0086 · UDR : 0082 §3.2 · enseignant seulement ; le contenu est celui du panneau de l'en-tête (shared/navigation/_account_panel)
module Classroom
  class TeacherMenusController < AuthenticatedController
    allow_roles :teacher

    def show; end
  end
end
