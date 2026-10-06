# 🧠 DOMAINE · Policies::Communication::ManageIllustrationsPolicy
# Rôle : écrire dans la bibliothèque d'illustrations d'annonce (ajout, renommage, retrait) : l'équipe seule
# ADR  : 0028, 0081 (§4.3)
module Policies
  module Communication
    # Toute personne connectée lit la bibliothèque (le choix des auteurs) ; seule l'équipe, quel que soit son rôle
    # d'équipe, l'écrit.
    class ManageIllustrationsPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
