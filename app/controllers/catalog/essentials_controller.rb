# 🌐 DELIVERY · Catalog::EssentialsController
# Rôle : l'ancienne adresse d'une notion (CA-12) : 301 vers la page de la leçon, ancrée sur la notion ; mêmes refus qu'avant (404), rien de révélé
# ADR  : 0028, 0035, 0113 (§4) · UDR : 0139 (§3.7)
module Catalog
  class EssentialsController < AuthenticatedController
    include ReadsOwnLevel

    def show
      essential = Repositories::Catalog::EssentialRepository.new.find_by_slug(slug: params[:slug])
      return render_not_found unless essential && in_course?(essential)
      return if refuse_out_of_level(course_id: essential.course_id)

      render_result Policies::Catalog::ReadPublishedPolicy.new.call(actor: current_actor, content: essential),
                    success: ->(_) {
                      redirect_to course_path(params[:course_slug], anchor: "notion-#{essential.slug}"), status: :moved_permanently
                    }
    end

    private

    # La notion lue sous un autre cours que le sien n'existe pas à cette adresse.
    def in_course?(essential)
      Repositories::Catalog::CourseRepository.new.find_by_slug(slug: params[:course_slug])&.id == essential.course_id
    end
  end
end
