# 🧠 DOMAINE · Policies::Classroom::PrintSchoolPostersPolicy
# Rôle : imprimer le kit d'affiches d'un établissement : l'équipe, ou la direction de cet établissement
# ADR  : partage-classe-k-factor · UDR : partage-de-classe (§3.2)
module Policies
  module Classroom
    class PrintSchoolPostersPolicy
      # school : répond à id. Hors de son établissement, la direction ne le voit pas : :not_found ; un élève : :forbidden.
      def call(actor:, school:)
        return Shared::Result.failure(:forbidden) if actor.nil? || actor.student?
        return Shared::Result.success if actor.team?
        return Shared::Result.success if actor.school_admin? && actor.school_id && actor.school_id == school.id

        Shared::Result.failure(:not_found)
      end
    end
  end
end
