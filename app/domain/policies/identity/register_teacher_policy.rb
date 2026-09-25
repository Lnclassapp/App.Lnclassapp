# 🧠 DOMAINE · Policies::Identity::RegisterTeacherPolicy
# Rôle : seul un visiteur anonyme s'inscrit comme enseignant
# ADR  : 0028, 0030
module Policies
  module Identity
    class RegisterTeacherPolicy
      def call(actor:)
        return Shared::Result.success if actor.nil?

        Shared::Result.failure(:forbidden, errors: { base: [ :already_signed_in ] })
      end
    end
  end
end
