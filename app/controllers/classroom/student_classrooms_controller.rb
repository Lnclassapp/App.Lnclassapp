# 🌐 DELIVERY · Classroom::StudentClassroomsController
# Rôle : « Ma classe » de l'élève (CL-22, CL-10 volet élève) : sa classe, les cours assignés, ses devoirs reçus en feuilles (un envoi, une feuille) et ses exercices traités
# ADR  : 0026, 0028, 0040 · UDR : 0006, 0011, 0076 · jamais la liste nominative ; sans classe active, l'accueil qui propose d'en choisir une
module Classroom
  class StudentClassroomsController < AuthenticatedController
    allow_roles :student

    def show
      @classroom = Queries::Classroom::StudentClassroomQuery.new.call(student_id: current_actor.user_id)
      return redirect_to student_home_path if @classroom.nil?

      @header = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: @classroom.public_id)
      render_result Policies::Classroom::ReadClassroomPolicy.new.call(actor: current_actor, classroom: @header),
                    success: ->(_access) { render_show }
    end

    private

    # Les devoirs reçus (un envoi, une feuille) ne se lisent qu'une fois la lecture de la classe accordée : jamais ceux d'une autre classe.
    def render_show
      @assigned_sheets = Queries::Classroom::StudentAssignedSheetsQuery.new.call(actor: current_actor)
      render :show
    end
  end
end
