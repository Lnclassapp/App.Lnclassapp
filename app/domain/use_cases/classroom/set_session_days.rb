# 🧠 DOMAINE · UseCases::Classroom::SetSessionDays
# Rôle : l'enseignant de la classe renseigne ou modifie ses jours de séance (au moins un) ; aucune assignation n'est touchée
# ADR  : 0026, 0028, 0072
module UseCases
  module Classroom
    class SetSessionDays
      Saved = Data.define(:classroom, :session_days)

      def initialize(classrooms:, session_days:, policy:, clock:)
        @classrooms = classrooms
        @session_days = session_days
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Classroom::SessionDaysInput ; au moins un jour (audit B-012).
      # → Result(Saved) | :not_found | :forbidden (y compris base: classroom_archived) | :invalid
      def call(actor:, dto:)
        classroom = @classrooms.find_by_public_id(public_id: dto.classroom_public_id)
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        # Les échéances déjà données ne changent pas (ADR-0072 §4.3) : seules les assignations suivantes liront ces jours.
        written = @session_days.replace(teacher_id: actor.user_id, classroom_id: classroom.id, weekdays: dto.weekdays, at: @clock.now)
        return Shared::Result.failure(:forbidden) unless written

        Shared::Result.success(Saved.new(classroom:, session_days: Entities::Classroom::SessionDays.new(weekdays: dto.weekdays)))
      end
    end
  end
end
