# 🌐 DELIVERY · Teams::BaseController
# Rôle : parent de l'espace équipe (Mission Control compris) ; fermé tant que l'authentification n'existe pas
# ADR  : 0052
module Teams
  class BaseController < ApplicationController
    # Closed by default: the team authentication arrives with V1 and replaces this guard.
    before_action :deny_access

    private

    def deny_access
      redirect_to main_app.root_path
    end
  end
end
