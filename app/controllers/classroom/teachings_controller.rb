# 🌐 DELIVERY · Classroom::TeachingsController
# Rôle : déclarer ou retirer une classe enseignée, en Turbo Stream (bascule et compteur) ; repli HTML : retour à la liste
# ADR  : 0026, 0028, 0030 · UDR : 0006, 0025
module Classroom
  class TeachingsController < AuthenticatedController
    allow_roles :teacher

    def create
      render_result declare.call(actor: current_actor, classroom_public_id: params[:classroom_public_id]),
                    success: ->(classroom) { respond_toggled(classroom, declared: true, notice: :declared) }
    end

    def destroy
      render_result withdraw.call(actor: current_actor, classroom_public_id: params[:classroom_public_id]),
                    success: ->(classroom) { respond_toggled(classroom, declared: false, notice: :withdrawn) }
    end

    private

    def respond_toggled(classroom, declared:, notice:)
      @classroom = Queries::Classroom::TeachingSelectionQuery::ClassroomRow.new(public_id: classroom.public_id,
                                                                                name: classroom.name, declared:)
      @selection = Queries::Classroom::TeachingSelectionQuery.new.call(teacher_id: current_actor.user_id,
                                                                       school_id: current_actor.school_id)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to teacher_classrooms_path, notice: t(".#{notice}", name: classroom.name), status: :see_other }
      end
    end

    def declare
      UseCases::Classroom::DeclareTeaching.new(**dependencies, clock: Time.zone)
    end

    def withdraw = UseCases::Classroom::WithdrawTeaching.new(**dependencies)

    def dependencies
      { classrooms: Repositories::Classroom::ClassroomRepository.new, teachings: Repositories::Classroom::TeachingRepository.new,
        policy: Policies::Classroom::DeclareTeachingPolicy.new }
    end
  end
end
