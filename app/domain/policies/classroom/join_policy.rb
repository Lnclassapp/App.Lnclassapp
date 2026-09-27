# 🧠 DOMAINE · Policies::Classroom::JoinPolicy
# Rôle : adhésion par code : visiteur ou élève, classe active, code courant, effectif sous le plafond
# ADR  : 0028, 0040, 0041
module Policies
  module Classroom
    class JoinPolicy
      # classroom : chargée sous verrou, avec active_students_count ; code : saisi par l'utilisateur
      def call(actor:, classroom:, code:)
        return Shared::Result.failure(:forbidden) unless actor.nil? || actor.student?
        return refuse(:classroom_archived) unless classroom.active?
        return refuse(:join_code_revoked) unless current_code?(classroom, code)
        return refuse(:classroom_full) if classroom.full?

        Shared::Result.success
      end

      private

      def current_code?(classroom, code)
        classroom.join_code.present? && classroom.join_code == Entities::Classroom::JoinCode.normalize(code)
      end

      def refuse(reason) = Shared::Result.failure(:forbidden, errors: { base: [ reason ] })
    end
  end
end
