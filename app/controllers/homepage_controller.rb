# 🌐 DELIVERY · HomepageController
# Rôle : sert la page d'accueil publique ; une personne connectée est envoyée vers son accueil
# ADR  : 0001, 0050
class HomepageController < ApplicationController
  allow_unauthenticated_access

  def index
    redirect_to_home if authenticated?
  end
end
