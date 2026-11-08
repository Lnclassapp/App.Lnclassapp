# 🧠 DOMAINE · Policies::Classroom::WithdrawTeachingPolicy
# Rôle : un enseignant se retire d'une classe de son école principale, archivée ou non (se déclarer, lui, exige une classe active)
# ADR  : 0028, 0030 · audit B-013
module Policies
  module Classroom
    class WithdrawTeachingPolicy
      def call(actor:, classroom:)
        return Shared::Result.failure(:forbidden) unless actor&.teacher?
        return Shared::Result.failure(:forbidden, errors: { base: [ :other_school ] }) if actor.school_id.nil? || actor.school_id != classroom.school_id

        Shared::Result.success
      end
    end
  end
end
