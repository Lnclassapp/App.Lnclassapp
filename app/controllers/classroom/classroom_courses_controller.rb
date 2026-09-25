# 🌐 DELIVERY · Classroom::ClassroomCoursesController
# Rôle : un cours vu depuis une classe (CL-11) : ses fiches essentielles publiées, chacune avec sa bascule d'assignation
# ADR  : 0026, 0028, 0048 · UDR : 0006, 0028
module Classroom
  class ClassroomCoursesController < AuthenticatedController
    # Comme la page de la classe (D4) : l'élève lit ses cours sur ses propres pages.
    allow_roles :teacher, :team

    def show
      @classroom = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:classroom_public_id])
      return render_not_found if @classroom.nil?

      render_result Policies::Classroom::ReadClassroomPolicy.new.call(actor: current_actor, classroom: @classroom),
                    success: ->(_access) { load_course }
    end

    private

    def load_course
      @course = Queries::Classroom::ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id,
                                                                  course_slug: params[:course_slug])
      render_not_found if @course.nil?
    end
  end
end
