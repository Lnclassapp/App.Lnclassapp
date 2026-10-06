# 🧠 DOMAINE · Policies::Communication::DismissPolicy
# Rôle : un élève masque (ou réaffiche) une annonce qu'il lit, sauf une annonce officielle, écrite par une direction
# ADR  : 0028, 0078 (§4.2)
module Policies
  module Communication
    class DismissPolicy
      # readable : la règle de lecture pour cet élève ; author_role : le rôle du compte auteur (officielle = direction).
      def call(actor:, readable:, author_role:)
        return Shared::Result.failure(:forbidden) unless actor&.student? && readable
        return Shared::Result.failure(:forbidden) if author_role == :school_admin

        Shared::Result.success
      end
    end
  end
end
