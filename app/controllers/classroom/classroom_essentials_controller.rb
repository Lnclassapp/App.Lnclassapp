# 🌐 DELIVERY · Classroom::ClassroomEssentialsController
# Rôle : une fiche essentielle vue depuis une classe (CL-12, AS-20) : élèves à revoir et fiche levée (AS-17), puis ses exercices
#        publiés, chacun avec sa bascule d'assignation ; l'enseignant sans jours de séance y ouvre la modale des jours
# ADR  : 0026, 0028, 0048, 0072, 0088, 0101 · UDR : 0006, 0028, 0029, 0062, 0121
module Classroom
  class ClassroomEssentialsController < AuthenticatedController
    # Comme la page de la classe (D4) : l'élève lit ses exercices sur ses propres pages.
    allow_roles :teacher, :team

    def show
      @classroom = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:classroom_public_id])
      # vie-de-la-classe, Lot C (ADR-0088, Q8) : une classe archivée n'a plus de page, quel que soit le rôle ; elle se restaure.
      return render_not_found if @classroom.nil? || @classroom.status == "archived"

      render_result Policies::Classroom::ReadClassroomPolicy.new.call(actor: current_actor, classroom: @classroom),
                    success: ->(access) { load_essential(access) }
    end

    private

    def load_essential(access)
      @essential = Queries::Classroom::ClassroomEssentialQuery.new.call(classroom_public_id: @classroom.public_id,
                                                                        course_slug: params[:course_slug],
                                                                        essential_slug: params[:essential_slug],
                                                                        teacher_id: (current_actor.user_id if current_actor.teacher?))
      return render_not_found if @essential.nil?

      # UDR-0121 §3.2 : qui est à revoir, qui a levé la fiche pendant l'année de la classe (ADR-0101 §4.4).
      @gaps = Queries::Assessment::ClassroomGapsQuery.new.detail(classroom_public_id: @classroom.public_id,
                                                                 course_slug: @essential.course_slug,
                                                                 essential_slug: @essential.essential.slug,
                                                                 school_year: @classroom.school_year, show_roster: access.show_roster)
    end
  end
end
