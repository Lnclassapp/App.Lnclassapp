# 🌐 DELIVERY · Classroom::CourseAssignmentsController
# Rôle : assigner un cours depuis sa page (CA-27) : une ligne par classe active de l'enseignant, avec la bascule de D5
# ADR  : 0026, 0035, 0048 · UDR : 0006, 0028, 0030
module Classroom
  class CourseAssignmentsController < AuthenticatedController
    allow_roles :teacher

    # Pas d'écriture ici : la bascule poste vers Classroom::AssignmentsController, dont les streams la remplacent.
    def index
      @targets = Queries::Classroom::CourseAssignmentTargetsQuery.new.call(teacher_id: current_actor.user_id,
                                                                           course_slug: params[:course_slug])
      render_not_found if @targets.nil?
    end
  end
end
