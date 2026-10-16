# 🧠 DOMAINE · Policies::School::LeaveSchoolPolicy
# Rôle : un enseignant quitte lui-même un de ses établissements, jamais son dernier
# ADR  : 0028, 0094
module Policies
  module School
    class LeaveSchoolPolicy
      # attached : il a une ligne teacher_schools pour cet établissement ; schools_count : tous ses rattachements.
      def call(actor:, attached:, schools_count:)
        return Shared::Result.failure(:forbidden) unless actor&.teacher?
        return Shared::Result.failure(:not_found) unless attached
        return Shared::Result.failure(:forbidden, errors: { base: [ :last_school ] }) if schools_count < 2

        Shared::Result.success
      end
    end
  end
end
