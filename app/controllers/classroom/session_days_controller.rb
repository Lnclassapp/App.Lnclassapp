# 🌐 DELIVERY · Classroom::SessionDaysController
# Rôle : l'enseignant de la classe modifie ses jours de séance dans la modale ouverte depuis la page de la classe ; succès :
#        toast et page rafraîchie par morphing ; tout décocher vaut « non renseigné » ; les échéances données ne bougent pas
# ADR  : 0026, 0028, 0072 · UDR : 0006, 0062 (§3.4)
module Classroom
  class SessionDaysController < AuthenticatedController
    allow_roles :teacher

    def edit
      @classroom = classrooms.find_by_public_id(public_id: params[:classroom_public_id])
      return render_not_found if @classroom.nil?

      render_result Policies::Classroom::SetSessionDaysPolicy.new.call(actor: current_actor, classroom: @classroom),
                    success: lambda { |_|
                      weekdays = session_days.for(teacher_id: current_actor.user_id, classroom_id: @classroom.id).weekdays
                      @form = Dtos::Classroom::SessionDaysInput.new(classroom_public_id: @classroom.public_id, weekdays:)
                    }
    end

    def update
      @form = Dtos::Classroom::SessionDaysInput.new(
        weekdays: params.fetch(:session_days, {}).permit(weekdays: [])[:weekdays], classroom_public_id: params[:classroom_public_id]
      )
      @classroom = classrooms.find_by_public_id(public_id: params[:classroom_public_id])
      render_result set_session_days.call(actor: current_actor, dto: @form), form: :edit, success: lambda { |saved|
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [ helpers.turbo_stream_toast(t(".saved"), type: :success), turbo_stream.refresh(request_id: nil) ]
          end
          format.html { redirect_to classroom_path(saved.classroom.public_id), notice: t(".saved"), status: :see_other }
        end
      }
    end

    private

    def classrooms = (@classrooms ||= Repositories::Classroom::ClassroomRepository.new)
    def session_days = (@session_days ||= Repositories::Classroom::SessionDaysRepository.new)

    def set_session_days
      UseCases::Classroom::SetSessionDays.new(classrooms:, session_days:, policy: Policies::Classroom::SetSessionDaysPolicy.new,
                                              clock: Time.zone)
    end
  end
end
