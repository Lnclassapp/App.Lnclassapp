# 🌐 DELIVERY · Classroom::ClassroomsController
# Rôle : page d'une classe (CL-10) pour l'enseignant qui y enseigne et l'équipe : en-tête, cours assignés, liste des élèves
# ADR  : 0026, 0028 · UDR : 0006, 0027 · un élève reçoit 403 : il voit le code de sa classe sur ses propres pages
module Classroom
  class ClassroomsController < AuthenticatedController
    allow_roles :teacher, :team

    def show
      @header = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:public_id])
      return render_not_found if @header.nil?

      render_result Policies::Classroom::ReadClassroomPolicy.new.call(actor: current_actor, classroom: @header),
                    success: ->(access) { @overview = overview(access) }
    end

    private

    def overview(access)
      Queries::Classroom::ClassroomOverviewQuery.new.call(public_id: @header.public_id, show_roster: access.show_roster)
    end
  end
end
