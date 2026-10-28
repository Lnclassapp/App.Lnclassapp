# 🌐 DELIVERY · Classroom::ClassroomEssentialsController
# Rôle : l'ancienne adresse d'une notion vue depuis une classe (CA-12) : 301 vers la leçon dans cette classe, ancrée sur la notion ; mêmes refus qu'avant, rien de révélé
# ADR  : 0028, 0048, 0088, 0113 (§4) · UDR : 0139 (§3.7)
module Classroom
  class ClassroomEssentialsController < AuthenticatedController
    # Comme la page de la classe (D4) : l'élève lit ses exercices sur ses propres pages.
    allow_roles :teacher, :team

    def show
      @classroom = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:classroom_public_id])
      # vie-de-la-classe, Lot C (ADR-0088, Q8) : une classe archivée n'a plus de page, quel que soit le rôle ; elle se restaure.
      return render_not_found if @classroom.nil? || @classroom.status == "archived"

      render_result Policies::Classroom::ReadClassroomPolicy.new.call(actor: current_actor, classroom: @classroom),
                    success: ->(_access) { redirect_to_lesson }
    end

    private

    # Une notion publiée d'une leçon publiée, lue sous sa leçon : sinon elle n'existe pas à cette adresse.
    def redirect_to_lesson
      slug = Queries::Catalog::PublishedEssentialQuery.new.slug(course_slug: params[:course_slug],
                                                                essential_slug: params[:essential_slug])
      return render_not_found if slug.nil?

      redirect_to classroom_course_path(@classroom.public_id, params[:course_slug], anchor: "notion-#{slug}"),
                  status: :moved_permanently
    end
  end
end
