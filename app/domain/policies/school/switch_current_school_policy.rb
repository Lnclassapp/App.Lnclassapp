# 🧠 DOMAINE · Policies::School::SwitchCurrentSchoolPolicy
# Rôle : un enseignant ne passe que dans un établissement auquel il est rattaché
# ADR  : 0028, 0094
module Policies
  module School
    class SwitchCurrentSchoolPolicy
      # attached : une ligne teacher_schools existe pour cet enseignant et cet établissement.
      def call(actor:, attached:)
        return Shared::Result.success if actor&.teacher? && attached

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
