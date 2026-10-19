# 🌐 DELIVERY · Catalog::LevelPagesController — liste publique des niveaux (/niveaux) et Espace Niveau (/niveaux/:slug)
# Rôle : lit PublicLevelsQuery, sans compte ni redirection ; un slug inconnu répond 404
# ADR  : 0099 (§4.2, §4.3) · UDR : 0113 (§3.2, §3.3) · PRD : CC-01 à CC-08
module Catalog
  class LevelPagesController < PublicController
    def index
      @levels = Queries::Catalog::PublicLevelsQuery.new.levels
    end

    def show
      @space = Queries::Catalog::PublicLevelsQuery.new.space(slug: slug_param(:slug)) or render_not_found
    end
  end
end
