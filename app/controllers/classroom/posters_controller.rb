# 🌐 DELIVERY · Classroom::PostersController
# Rôle : l'affiche A4 d'une classe (nom, établissement, QR du lien, 3 étapes), page à imprimer sans navigation ; classe archivée ou hors périmètre : 404
# ADR  : partage-classe-k-factor · UDR : partage-de-classe (§3.2) · IL-12 : ManageClassroomMembersPolicy (autre classe : 404, élève : 403)
module Classroom
  class PostersController < AuthenticatedController
    allow_roles :teacher, :school_admin, :team

    def show
      classroom = Repositories::Classroom::ClassroomRepository.new.find_by_public_id(public_id: params[:public_id])
      return render_not_found if classroom.nil?

      render_result Policies::Classroom::ManageClassroomMembersPolicy.new.call(actor: current_actor, classroom:), success: lambda { |_|
        @poster = Queries::Classroom::PosterQuery.new.for_classroom(public_id: classroom.public_id) if classroom.active?
        return render_not_found if @poster.nil?

        @classroom_public_id = classroom.public_id
        render layout: "print"
      }
    end
  end
end
