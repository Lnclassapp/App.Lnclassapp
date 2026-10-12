# 🌐 DELIVERY · Classroom::StudentMenusController
# Rôle : panneau du compte de l'élève rendu comme une page (/students/menu) : ouvert en modale par l'app, repli sans JavaScript du site
# ADR  : 0084 · UDR : 0080 §3.2 · élève seulement ; le contenu est celui du panneau de l'en-tête (shared/navigation/_account_panel)
module Classroom
  class StudentMenusController < AuthenticatedController
    allow_roles :student

    def show; end
  end
end
