# 🧠 DOMAINE · Policies::Classroom::AssignPolicy
# Rôle : assigner ou archiver une ressource : comme TeachPolicy, sur une classe active
# ADR  : 0028, 0041, 0048
module Policies
  module Classroom
    class AssignPolicy
      def call(actor:, classroom:)
        teach = TeachPolicy.new.call(actor:, classroom:)
        return teach if teach.failure?
        return Shared::Result.failure(:forbidden, errors: { base: [ :classroom_archived ] }) unless classroom.active?

        Shared::Result.success
      end
    end
  end
end
