# 🧠 DOMAINE · Policies::Catalog::ReadPublishedPolicy
# Rôle : un non-team ne lit qu'un contenu publié dont toute la chaîne de parents est publiée
# ADR  : 0028, 0035
module Policies
  module Catalog
    class ReadPublishedPolicy
      # content répond à readable_chain_published? (cours, fiche ou exercice)
      def call(actor:, content:)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success if actor.team?
        return Shared::Result.success if content.readable_chain_published?

        # On ne confirme pas l'existence d'un brouillon.
        Shared::Result.failure(:not_found)
      end
    end
  end
end
