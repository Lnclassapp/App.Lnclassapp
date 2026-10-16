# 🌐 DELIVERY · Classroom::ClassroomStudentsController
# Rôle : fiche d'un élève dans sa classe (CL-13) ; retrait (IL-14) en Turbo Stream, ou 303 vers la classe depuis la fiche (origin=file)
# ADR  : 0028, 0065, 0085 (§4.5), 0097 · UDR : 0006, 0081 (§3.7), 0107 · 403 et 404 par RendersResult ; `q` : la recherche de la liste
module Classroom
  class ClassroomStudentsController < AuthenticatedController
    allow_roles :teacher, :school_admin, :team

    # ADR-0097 §4.1, §4.2 : classe inconnue ou archivée, 404 ; la policy avant toute lecture de l'élève (un enseignant
    # d'une autre classe reçoit 403, jamais une indication de présence) ; élève absent de la classe, 404.
    def show
      @header = Queries::Classroom::ClassroomHeaderQuery.new.call(public_id: params[:classroom_public_id])
      return render_not_found if @header.nil? || @header.status == "archived"

      render_result read_roster_policy, success: ->(_) { load_file }
    end

    def destroy
      render_result remove_student.call(actor: current_actor, classroom_public_id: params[:classroom_public_id],
                                        student_public_id: params[:student_public_id]),
                    success: ->(removal) { respond_removed(removal) }
    end

    private

    # La fiche lit la liste des élèves : ReadClassroomPolicy sans show_roster (l'élève de la classe) est un refus.
    def read_roster_policy
      result = Policies::Classroom::ReadClassroomPolicy.new.call(actor: current_actor, classroom: @header)
      result.failure? || result.value.show_roster ? result : Shared::Result.failure(:forbidden)
    end

    def load_file
      @file = Queries::Classroom::StudentFileQuery.new.call(classroom_public_id: @header.public_id,
                                                            student_public_id: params[:student_public_id])
      return render_not_found if @file.nil?

      @can_remove = Policies::Classroom::ManageClassroomMembersPolicy.new.call(actor: current_actor, classroom: @header).success?
    end

    # Un second retrait (IL-21) répond comme le premier : la ligne part, le compte est relu, aucune erreur.
    # Depuis la fiche (UDR-0107 §3.6, origin=file), la fiche n'existe plus : 303 vers la page de la classe, quel que soit le format.
    def respond_removed(removal)
      @student = removal.student
      @notice = t("classroom.classrooms.roster.removed", name: @student.display_name)
      public_id = removal.classroom.public_id
      return redirect_to(classroom_page(public_id), notice: @notice, status: :see_other) if params[:origin] == "file"

      respond_to do |format|
        format.turbo_stream do
          @direction_page = current_actor.school_admin?
          read_roster(public_id)
        end
        format.html { redirect_to classroom_page(public_id), notice: @notice, status: :see_other }
      end
    end

    # La direction n'a que sa page de classe (school_admin/classrooms/show) : son titre de liste est recompté ici, le reste
    # de sa page est re-demandé par le stream (destroy.turbo_stream.erb).
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
