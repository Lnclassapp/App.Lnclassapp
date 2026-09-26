# 🌐 DELIVERY · Catalog::EssentialsController
# Rôle : page d'une fiche essentielle (CA-11, AS-37) : contenu, exercices, progression de l'élève, menu de l'équipe
# ADR  : 0026, 0028, 0035 · UDR : 0006, 0007, 0015
module Catalog
  class EssentialsController < AuthenticatedController
    def show
      essential = Repositories::Catalog::EssentialRepository.new.find_by_slug(slug: params[:slug])
      return render_not_found if essential.nil?

      render_result Policies::Catalog::ReadPublishedPolicy.new.call(actor: current_actor, content: essential),
                    success: ->(_) { load_page(essential) }
    end

    private

    # L'entité ne sert qu'à la policy et au panneau de statut de l'équipe ; la vue lit la query.
    def load_page(essential)
      team = Policies::Catalog::ManageContentPolicy.new.call(actor: current_actor).success?
      @detail = Queries::Catalog::EssentialDetailQuery.new.call(course_slug: params[:course_slug], slug: essential.slug,
                                                                student_id:, include_unpublished: team)
      return render_not_found if @detail.nil?

      @status_record = essential if team
      @student = current_actor.student?
    end

    def student_id
      current_actor.user_id if current_actor.student?
    end
  end
end
