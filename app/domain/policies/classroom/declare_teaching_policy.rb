# 🧠 DOMAINE · Policies::Classroom::DeclareTeachingPolicy
# Rôle : un enseignant se déclare (ou se retire) dans une classe active de son école principale
# ADR  : 0028, 0030
module Policies
  module Classroom
    class DeclareTeachingPolicy
      def call(actor:, classroom:)
        return Shared::Result.failure(:forbidden) unless actor&.teacher?
        return refuse(:other_school) if actor.school_id.nil? || actor.school_id != classroom.school_id
        return refuse(:classroom_archived) unless classroom.active?

        Shared::Result.success
      end

      private

      def refuse(reason) = Shared::Result.failure(:forbidden, errors: { base: [ reason ] })
    end
  end
end
