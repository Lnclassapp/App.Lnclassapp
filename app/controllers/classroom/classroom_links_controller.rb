# 🌐 DELIVERY · Classroom::ClassroomLinksController
# Rôle : « Changer le lien » d'une classe : nouveau jeton, bloc #classroom_link remplacé et toast ; repli HTML vers la page d'origine
# ADR  : 0026, 0028, 0083 (§4.1) · UDR : 0079 (§3.6) · IL-12 : ManageClassroomMembersPolicy (autre classe : 404, élève : 403)
module Classroom
  class ClassroomLinksController < AuthenticatedController
    allow_roles :teacher, :school_admin, :team

    def update
      render_result change_link.call(actor: current_actor, public_id: params[:public_id]), success: lambda { |classroom|
        @classroom = classroom
        respond_to do |format|
          format.turbo_stream
          format.html do
            redirect_back_or_to classroom_path(classroom.public_id), notice: t("classroom.classrooms.link.changed"),
                                                                     status: :see_other
          end
        end
      }
    end

    private

    def change_link
      UseCases::Classroom::ChangeClassroomLink.new(classrooms: Repositories::Classroom::ClassroomRepository.new,
                                                   policy: Policies::Classroom::ManageClassroomMembersPolicy.new,
                                                   transaction: Repositories::Shared::Transaction.new)
    end
  end
end
