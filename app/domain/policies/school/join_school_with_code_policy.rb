# 🧠 DOMAINE · Policies::School::JoinSchoolWithCodePolicy
# Rôle : rejoindre un établissement par son code : l'enseignant sans établissement ni demande en attente
# ADR  : 0028, 0063, 0071
module Policies
  module School
    class JoinSchoolWithCodePolicy
      # pending_request : sa demande en attente, ou nil. Une demande décidée (approuvée, refusée) n'empêche pas : l'appelant
      # ne la passe pas.
      def call(actor:, pending_request:)
        return Shared::Result.success if actor&.teacher? && actor.school_id.nil? && pending_request.nil?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
