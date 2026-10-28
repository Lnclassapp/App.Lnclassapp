# 🌐 DELIVERY · Catalog::CourseSheetsController
# Rôle : l'ancienne adresse de la fiche de cours (CA-12) : 301 vers la fiche de révision de la page de la leçon ; mêmes refus qu'avant (404), rien de révélé
# ADR  : 0110-fiche-de-cours-en-donnees-importees, 0028, 0035, 0113 (§4) · UDR : 0139 (§3.7)
module Catalog
  class CourseSheetsController < AuthenticatedController
    include ReadsOwnLevel

    def show
      sheet = Queries::Catalog::CourseSheetQuery.new.call(course_slug: params[:course_slug])
      return render_not_found if sheet.nil?
      return if refuse_out_of_level(course_slug: params[:course_slug])

      render_result Policies::Catalog::ReadPublishedPolicy.new.call(actor: current_actor, content: sheet),
                    success: ->(_) {
                      redirect_to course_path(params[:course_slug], anchor: "fiche-de-revision"), status: :moved_permanently
                    }
    end
  end
end
