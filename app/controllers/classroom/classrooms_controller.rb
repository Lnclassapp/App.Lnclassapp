# 🌐 DELIVERY · Classroom::ClassroomsController
# Rôle : page d'une classe (CL-10), enseignant qui y enseigne et équipe : jours de séance, exercices assignés, cours, élèves (`q`)
# ADR  : 0026, 0028, 0072 · UDR : 0006, 0027, 0054, 0062 · un élève reçoit 403 : il voit le code de sa classe sur ses propres pages
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

    # « Chercher un élève » (UDR-0054 §3.9) : la recherche filtre la liste déjà accordée par la policy, jamais plus.
    # Les comptes des exercices assignés suivent FollowAssignmentPolicy (ADR-0072 §4.5) ; jours et matière : l'enseignant.
    def overview(access)
      @search = params[:q].to_s
      follow = Policies::Classroom::FollowAssignmentPolicy.new.call(actor: current_actor, classroom: @header)
      Queries::Classroom::ClassroomOverviewQuery.new.call(public_id: @header.public_id, show_roster: access.show_roster,
                                                          search: @search, show_follow_up: follow.success?,
                                                          teacher_id: (current_actor.user_id if current_actor.teacher?))
    end
  end
end
