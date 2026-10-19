# 🌐 DELIVERY · Catalog::MaterialPagesController — page publique d'une matière (/matieres/:slug), filtrée par ?niveau= et ?serie=
# Rôle : lit PublicMaterialQuery, sans compte ni redirection ; adresses inconnues en 404 ; la page suivante dans son frame différé
# ADR  : 0099 (§4.2, §4.3), 0076 (§4.2) · UDR : 0114 (§3.1, §3.3) · PRD : CC-09 à CC-13, CC-17
module Catalog
  class MaterialPagesController < PublicController
    # La page suivante, demandée par le frame différé posé au bas de la précédente (comme Catalog::CoursesController).
    PAGE_FRAME = /\Amaterial_courses_page_\d+\z/

    helper_method :after_level

    def show
      @page = Queries::Catalog::PublicMaterialQuery.new.call(slug: slug_param(:slug), level: slug_param(:niveau),
                                                             series: slug_param(:serie), page: params[:page])
      return render_not_found unless @page

      render partial: "page_frame", locals: { page: @page } if PAGE_FRAME.match?(turbo_frame_request_id.to_s)
    end

    private

    # Le niveau de la dernière carte de la page précédente, dont le titre de groupe est déjà rendu. Toujours une chaîne.
    def after_level = params[:after_level].to_s
  end
end
