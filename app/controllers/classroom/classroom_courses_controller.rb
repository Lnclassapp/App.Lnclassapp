# 🌐 DELIVERY · Classroom::ClassroomCoursesController
# Rôle : une leçon vue depuis une classe (CL-11) : « Fiche de révision », « Prépare interros » et « Prépare devoirs », avec les bascules d'assignation de cette classe
# ADR  : 0026, 0028, 0048, 0088, 0113, 0121 · UDR : 0006, 0028, 0139 §3.4, 0149 §3
module Classroom
  class ClassroomCoursesController < AuthenticatedController
    # Comme la page de la classe (D4) : l'élève lit ses cours sur ses propres pages.
    allow_roles :teacher, :team

    def show
      @classroom = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:classroom_public_id])
      # vie-de-la-classe, Lot C (ADR-0088, Q8) : une classe archivée n'a plus de page, quel que soit le rôle ; elle se restaure.
      return render_not_found if @classroom.nil? || @classroom.status == "archived"

      render_result Policies::Classroom::ReadClassroomPolicy.new.call(actor: current_actor, classroom: @classroom),
                    success: ->(_access) { load_course }
    end

    private

    def load_course
      @course = Queries::Classroom::ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id,
                                                                  course_slug: params[:course_slug])
      return render_not_found if @course.nil?

      # Les deux sections de la page de la leçon (UDR-0139) : l'enseignant n'y voit que les bascules de cette classe.
      @revision = Queries::Catalog::RevisionSheetQuery.new.call(course_slug: params[:course_slug], actor: current_actor)
      @prepare = Queries::Catalog::PrepareSheetsQuery.new.call(course_slug: params[:course_slug], actor: current_actor)
    end
  end
end
