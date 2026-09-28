# 🧠 DOMAINE · Policies::School::VouchPolicy
# Rôle : un garant est un enseignant du même établissement, actif, qui n'est pas le demandeur ; l'équipe valide ailleurs
# ADR  : 0028, 0063
module Policies
  module School
    class VouchPolicy
      # request : Entities::School::JoinRequest ; school : son établissement.
      def call(actor:, request:, school:)
        return Shared::Result.failure(:forbidden) unless actor&.teacher? && school&.active?
        return Shared::Result.failure(:forbidden) unless actor.school_id == request.school_id && actor.user_id != request.teacher_id

        Shared::Result.success
      end
    end
  end
end
