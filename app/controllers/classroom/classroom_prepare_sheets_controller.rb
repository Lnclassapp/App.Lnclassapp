# 🌐 DELIVERY · Classroom::ClassroomPrepareSheetsController
# Rôle : le sujet d'une feuille de la leçon, lu par l'enseignant depuis sa classe, avec les bascules d'envoi de cette classe seulement ; mêmes refus que la leçon dans la classe
# ADR  : 0026, 0028, 0048, 0088, 0121 · UDR : feuilles-en-cases-lues-avant-de-commencer §3, 0149 §3 · :sheet = l'ancre de la feuille (notion-<slug>, toute-la-lecon, sujet-<n>)
module Classroom
  class ClassroomPrepareSheetsController < AuthenticatedController
    # Comme la leçon dans la classe : l'élève lit ses devoirs sur ses propres pages.
    allow_roles :teacher, :team, :school_admin

    def show
      @classroom = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:classroom_public_id])
      return render_not_found if @classroom.nil? || @classroom.status == "archived"

      render_result Policies::Classroom::ReadClassroomLessonPolicy.new.call(actor: current_actor, classroom: @classroom),
                    success: ->(access) { @can_assign = access.can_assign; load_course }
    end

    private

    helper_method :sheet_mode

    def load_course
      @course = Queries::Classroom::ClassroomCourseQuery.new.call(classroom_public_id: @classroom.public_id, course_slug: params[:course_slug])
      return render_not_found if @course.nil?

      @prepare = Queries::Catalog::PrepareSheetsQuery.new.call(course_slug: params[:course_slug], actor: current_actor,
                                                                  classroom_public_id: @classroom.public_id)
      @sheet = @prepare.sheet(params[:sheet])
      return redirect_to classroom_course_path(@classroom.public_id, params[:course_slug]), alert: t("catalog.courses.sheets.gone"), status: :see_other if @sheet.nil?

      # Contrat gelé (suivi-classe-lecon, Lot 0) : { public_id de l'exercice => ClassSuccess }, une requête ; {} jusqu'au Lot B.
      @success = Queries::Assessment::ClassExerciseSuccessQuery.new.call(
        classroom_public_id: @classroom.public_id, exercise_ids: @sheet.exercises.map(&:public_id)
      )
      render :show
    end

    # Dans la classe l'équipe a la barre de l'enseignant (suivi-classe-lecon, UDR §3.5) : le mode :team ne la rend pas.
    def sheet_mode = :teacher
  end
end
