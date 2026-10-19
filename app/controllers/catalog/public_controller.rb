# 🌐 DELIVERY · Catalog::PublicController — parent des pages publiques du catalogue (niveaux, série, matière)
# Rôle : lisibles sans compte, layout application sans shell, sans redirection d'une personne connectée ni cache partagé
# ADR  : 0099 (§4.2, §4.5), 0076 (§4.1) · UDR : 0113 (§3.1)
module Catalog
  class PublicController < ApplicationController
    allow_unauthenticated_access

    private

    # Un slug lu dans l'adresse, toujours une chaîne : une valeur forgée (tableau, hash) ne vaut aucun slug et répond 404.
    def slug_param(key) = params[key].to_s.presence
  end
end
