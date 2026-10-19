# 🌐 DELIVERY · Catalog::SeriesPagesController — page publique d'un niveau et de sa série (/niveaux/:level_slug/:series_slug)
# Rôle : lit PublicSeriesQuery, sans compte ni redirection ; un couple inconnu ou une série non rattachée au niveau répond 404
# ADR  : 0099 (§4.2, §4.3) · UDR : 0115 (§3.1) · PRD : CC-14 à CC-18
module Catalog
  class SeriesPagesController < PublicController
    def show
      @result = Queries::Catalog::PublicSeriesQuery.new.call(level_slug: slug_param(:level_slug),
                                                             series_slug: slug_param(:series_slug)) or render_not_found
    end
  end
end
