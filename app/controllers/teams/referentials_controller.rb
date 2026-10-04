# 🌐 DELIVERY · Teams::ReferentialsController
# Rôle : page « Référentiel » de l'équipe (RE-03) : tuiles des DRENA, niveaux, séries, matières et barème, structure scolaire
# ADR  : 0026, 0028, 0034, 0058 · UDR : 0018, 0068 (§3.4) · garde : celle de BaseController (équipe seule, 403 sinon)
module Teams
  class ReferentialsController < BaseController
    # La lecture de l'ancienne section de l'accueil, sans cache : un compteur suit la dernière création.
    def show
      @home = Queries::Catalog::TeamHomeQuery.new.call
    end
  end
end
