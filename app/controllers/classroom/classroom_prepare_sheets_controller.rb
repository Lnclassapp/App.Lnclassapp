# 🌐 DELIVERY · Classroom::ClassroomPrepareSheetsController
# Rôle : le sujet d'une feuille de la leçon, lu par l'enseignant depuis sa classe, avec les bascules d'envoi de cette classe seulement ; mêmes refus que la leçon dans la classe
# ADR  : 0026, 0028, 0048, 0088, 0121 · UDR : feuilles-en-cases-lues-avant-de-commencer §3, 0149 §3 · :sheet = l'ancre de la feuille (notion-<slug>, toute-la-lecon, sujet-<n>)
module Classroom
  class ClassroomPrepareSheetsController < AuthenticatedController
    # Comme la leçon dans la classe : l'élève lit ses devoirs sur ses propres pages.
    allow_roles :teacher, :team

    def show
      @classroom = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:classroom_public_id])
      return render_not_found if @classroom.nil? || @classroom.status == "archived"

      render_result Policies::Classroom::ReadClassroomPolicy.new.call(actor: current_actor, classroom: @classroom),
                    success: ->(_access) { load_course }
    end

    private

    helper_method :sheet_mode

    def load_course
      @course = Queries::Classroom::ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id, course_slug: params[:course_slug])
      return render_not_found if @course.nil?

      @prepare = Queries::Catalog::PrepareSheetsQuery.new.call(course_slug: params[:course_slug], actor: current_actor)
      @sheet = @prepare.sheet(params[:sheet])
      return redirect_to classroom_course_path(@classroom.public_id, params[:course_slug]), alert: t("catalog.courses.sheets.gone"), status: :see_other if @sheet.nil?

      render :show
    end

    def sheet_mode = current_actor.team? ? :team : :teacher
  end
end
