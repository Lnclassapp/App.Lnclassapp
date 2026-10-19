# 🌐 DELIVERY · Classroom::ClassroomsController
# Rôle : page d'une classe (CL-10), enseignant qui y enseigne et équipe : jours de séance, exercices assignés, cours, fiches à revoir, élèves (`q`, retrait)
# ADR  : 0026, 0028, 0072, 0085, 0088, 0101 · UDR : 0006, 0027, 0054, 0062, 0081 (§3.7), 0121 · un élève reçoit 403 : il voit le code de sa classe sur ses propres pages
module Classroom
  class ClassroomsController < AuthenticatedController
    allow_roles :teacher, :team

    def show
      @header = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:public_id])
      # ADR-0088 : une classe archivée n'a plus de page ; elle se restaure depuis le menu ⋮ de l'établissement.
      return render_not_found if @header.nil? || @header.status == "archived"

      render_result Policies::Classroom::ReadClassroomPolicy.new.call(actor: current_actor, classroom: @header),
                    success: ->(access) { @overview = overview(access).tap { @gaps = gaps(access, it) } }
    end

    private

    # « Chercher un élève » (UDR-0054 §3.9) : la recherche filtre la liste déjà accordée par la policy, jamais plus.
    # Les comptes des exercices assignés suivent FollowAssignmentPolicy (ADR-0072 §4.5) ; jours et matière : l'enseignant.
    def overview(access)
      @search = params[:q].to_s
      follow = Policies::Classroom::FollowAssignmentPolicy.new.call(actor: current_actor, classroom: @header)
      @can_remove_students = can_remove_students?
      Queries::Classroom::ClassroomOverviewQuery.new.call(public_id: @header.public_id, show_roster: access.show_roster,
                                                          search: @search, show_follow_up: follow.success?,
                                                          teacher_id: (current_actor.user_id if current_actor.teacher?))
    end

    # UDR-0121 §3.1 : les fiches à revoir des cours que la page affiche ; rien n'est lu sans show_roster (ADR-0101 §4.4).
    def gaps(access, overview)
      Queries::Assessment::ClassroomGapsQuery.new.summary(classroom_public_id: @header.public_id, show_roster: access.show_roster,
                                                          course_slugs: overview.courses.map(&:slug))
    end

    # UDR-0081 §3.7 : « Retirer de la classe » suit ManageClassroomMembersPolicy (ADR-0085 §4.5). L'en-tête n'a pas de
    # school_id : la policy ne le lit que pour la direction, que cette page n'admet pas (allow_roles).
    def can_remove_students?
      Policies::Classroom::ManageClassroomMembersPolicy.new.call(actor: current_actor, classroom: @header).success?
    end
  end
end
