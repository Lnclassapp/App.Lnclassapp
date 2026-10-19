# 🧠 DOMAINE · Policies::School::JoinSchoolWithCodePolicy
# Rôle : rejoindre un établissement : l'enseignant sans demande en attente, sous le plafond de 3 établissements
# ADR  : 0028, 0063, 0071, 0094
module Policies
  module School
    class JoinSchoolWithCodePolicy
      # pending_request : sa demande en attente, ou nil. Une demande décidée (approuvée, refusée) n'empêche pas : l'appelant
      # ne la passe pas. schools_count : ses rattachements ; 0, l'écran d'attente ; 1 ou 2, un établissement de plus
      # (ADR-0094 §4.3).
      def call(actor:, pending_request:, schools_count:)
        return Shared::Result.failure(:forbidden) unless actor&.teacher? && pending_request.nil?
        return Shared::Result.failure(:forbidden, errors: { base: [ :schools_limit ] }) if schools_count >= Entities::School::TeacherSchools::MAX

        Shared::Result.success
      end
    end
  end
end
