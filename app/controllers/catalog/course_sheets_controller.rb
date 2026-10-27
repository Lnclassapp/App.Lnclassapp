# 🌐 DELIVERY · Catalog::CourseSheetsController
# Rôle : la fiche de cours d'une leçon (CA-4, CA-5) : lue par l'élève de son niveau quand la leçon est publiée, par l'équipe toujours
# ADR  : XXXX-fiche-de-cours-en-donnees-importees (contenu-en-blocs, #318), 0028, 0035 · UDR : XXXX-fiche-de-cours-a-l-identique-des-maquettes
module Catalog
  class CourseSheetsController < AuthenticatedController
    include ReadsOwnLevel

    def show
      @sheet = Queries::Catalog::CourseSheetQuery.new.call(course_slug: params[:course_slug])
      return render_not_found if @sheet.nil?
      return if refuse_out_of_level(course_slug: params[:course_slug])

      render_result Policies::Catalog::ReadPublishedPolicy.new.call(actor: current_actor, content: @sheet),
                    success: ->(_) { }
    end
  end
end
