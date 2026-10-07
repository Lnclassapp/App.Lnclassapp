# 🌐 DELIVERY · Classroom::ClassroomStudentsController
# Rôle : retirer un élève de la classe (IL-14), en Turbo Stream : ligne, titre de la liste, effectif, toast ; repli HTML : retour à la classe
# ADR  : 0028, 0083 (§4.5) · UDR : 0006, 0079 (§3.7) · 403 et 404 en toast (RendersResult) ; `q` : la recherche de la liste, pour son compte
module Classroom
  class ClassroomStudentsController < AuthenticatedController
    allow_roles :teacher, :school_admin, :team

    def destroy
      render_result remove_student.call(actor: current_actor, classroom_public_id: params[:classroom_public_id],
                                        student_public_id: params[:student_public_id]),
                    success: ->(removal) { respond_removed(removal) }
    end

    private

    # Un second retrait (IL-21) répond comme le premier : la ligne part, le compte est relu, aucune erreur.
    def respond_removed(removal)
      @student = removal.student
      @notice = t("classroom.classrooms.roster.removed", name: @student.display_name)
      public_id = removal.classroom.public_id
      respond_to do |format|
        format.turbo_stream { read_roster(public_id) }
        format.html { redirect_to classroom_page(public_id), notice: @notice, status: :see_other }
      end
    end

    def read_roster(public_id)
      @search = params[:q].to_s
      @header = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id:)
      @overview = Queries::Classroom::ClassroomOverviewQuery.new.call(public_id:, show_roster: true, search: @search)
    end

    # La direction a sa propre page de classe (ADR-0065) ; l'enseignant et l'équipe, celle-ci.
    def classroom_page(public_id)
      current_actor.school_admin? ? school_admin_classroom_path(public_id) : classroom_path(public_id)
    end

    def remove_student
      UseCases::Classroom::RemoveStudent.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, memberships: Repositories::Classroom::MembershipRepository.new,
        users: Repositories::Identity::UserRepository.new, policy: Policies::Classroom::ManageClassroomMembersPolicy.new,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end
