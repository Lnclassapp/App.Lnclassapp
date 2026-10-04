# 🌐 DELIVERY · Classroom::ClassroomEssentialsController
# Rôle : une fiche essentielle vue depuis une classe (CL-12, AS-20) : ses exercices publiés, chacun avec sa bascule d'assignation ;
#        l'enseignant sans jours de séance y ouvre la modale des jours
# ADR  : 0026, 0028, 0048, 0072 · UDR : 0006, 0028, 0029, 0062
module Classroom
  class ClassroomEssentialsController < AuthenticatedController
    # Comme la page de la classe (D4) : l'élève lit ses exercices sur ses propres pages.
    allow_roles :teacher, :team

    def show
      @classroom = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:classroom_public_id])
      return render_not_found if @classroom.nil?

      render_result Policies::Classroom::ReadClassroomPolicy.new.call(actor: current_actor, classroom: @classroom),
                    success: ->(_access) { load_essential }
    end

    private

    def load_essential
      @essential = Queries::Classroom::ClassroomEssentialQuery.new.call(classroom_public_id: @classroom.public_id,
                                                                        course_slug: params[:course_slug],
                                                                        essential_slug: params[:essential_slug],
                                                                        teacher_id: (current_actor.user_id if current_actor.teacher?))
      render_not_found if @essential.nil?
    end
  end
end
