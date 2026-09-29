# 🧠 DOMAINE · Policies::School::ReadOwnSchoolPolicy
# Rôle : lire les pages de la direction : un compte de direction rattaché ; l'établissement lu est toujours le sien
# ADR  : 0028, 0065
module Policies
  module School
    class ReadOwnSchoolPolicy
      def call(actor:)
        return Shared::Result.success if actor&.school_admin? && actor.school_id

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
