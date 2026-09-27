# 🌐 DELIVERY · Teams::BaseController
# Rôle : parent de l'espace équipe (Mission Control compris) ; réservé à l'équipe, second facteur vérifié
# ADR  : 0028, 0031, 0052
module Teams
  class BaseController < AuthenticatedController
    # Un compte team non vérifié n'a pas d'acteur : la garde du second facteur l'arrête avant ce filtre.
    allow_roles :team
  end
end
