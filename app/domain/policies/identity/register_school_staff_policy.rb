# 🧠 DOMAINE · Policies::Identity::RegisterSchoolStaffPolicy
# Rôle : seul un visiteur anonyme s'inscrit comme direction avec le code d'établissement
# ADR  : 0028, 0077
module Policies
  module Identity
    class RegisterSchoolStaffPolicy
      def call(actor:)
        return Shared::Result.success if actor.nil?

        Shared::Result.failure(:forbidden, errors: { base: [ :already_signed_in ] })
      end
    end
  end
end
