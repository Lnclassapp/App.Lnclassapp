# 🌐 DELIVERY · SchoolAdmin::BaseController
# Rôle : parent de l'espace direction ; réservé à la direction, second facteur vérifié, établissement actif (celui de l'acteur)
# ADR  : 0028, 0031, 0066 · UDR : 0052
module SchoolAdmin
  class BaseController < AuthenticatedController
    # Un compte non vérifié n'a pas d'acteur : la garde du second facteur (Authentication) l'arrête avant ce filtre. Une
    # direction sans établissement est renvoyée vers l'écran d'attente avant lui (AuthenticatedController#hold_detached_school_admin) :
    # ici, current_actor.school_id est toujours l'établissement actif de l'acteur, le seul que lit un contrôleur de l'espace.
    allow_roles :school_admin
  end
end
