# 🌐 DELIVERY · Catalog::EssentialsController
# Rôle : l'ancienne adresse d'une notion (CA-12) : 302 vers la page de la leçon (l'élève : sa fiche de révision), ancrée sur la notion ; mêmes refus qu'avant (404), rien de révélé
# ADR  : 0028, 0035, 0113 (§4) · UDR : 0139 (§3.7)
module Catalog
  class EssentialsController < AuthenticatedController
    include ReadsOwnLevel

    def show
      essential = Repositories::Catalog::EssentialRepository.new.find_by_slug(slug: params[:slug])
      return render_not_found unless essential && in_course?(essential)
      return if refuse_out_of_level(course_id: essential.course_id) || refuse_out_of_material(course_id: essential.course_id)

      render_result Policies::Catalog::ReadPublishedPolicy.new.call(actor: current_actor, content: essential),
                    success: ->(_) { redirect_to notion_location(essential), status: :found }
    end

    private

    # L'élève lit la notion dans la fiche de révision, sur sa propre page (UDR XXXX écrans minimalistes style Wave §3) ; les autres, sur la page de la leçon.
    def notion_location(essential)
      anchor = "notion-#{essential.slug}"
      current_actor.student? ? course_fiche_path(params[:course_slug], anchor:) : course_path(params[:course_slug], anchor:)
    end

    # La notion lue sous un autre cours que le sien n'existe pas à cette adresse.
    def in_course?(essential)
      Repositories::Catalog::CourseRepository.new.find_by_slug(slug: params[:course_slug])&.id == essential.course_id
    end
  end
end
