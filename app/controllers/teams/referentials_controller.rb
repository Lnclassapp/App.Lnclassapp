# 🌐 DELIVERY · Teams::ReferentialsController
# Rôle : page « Référentiel » de l'équipe (RE-03) : tuiles des DRENA, niveaux, séries, matières, barème et illustrations d'annonce, structure scolaire
# ADR  : 0026, 0028, 0034, 0058, 0081 · UDR : 0018, 0068 (§3.4), 0075 (§3.6) · garde : celle de BaseController (équipe seule, 403 sinon)
module Teams
  class ReferentialsController < BaseController
    # La lecture de l'ancienne section de l'accueil, sans cache : un compteur suit la dernière création. La tuile des
    # illustrations d'annonce reçoit son compte de la bibliothèque (UDR-0075 §3.6).
    def show
      @home = Queries::Catalog::TeamHomeQuery.new.call
      @illustrations_count = Queries::Communication::IllustrationLibraryQuery.new.count
    end
  end
end
