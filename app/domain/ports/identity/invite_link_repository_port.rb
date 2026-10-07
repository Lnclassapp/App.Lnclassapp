# 🧠 DOMAINE · Ports::Identity::InviteLinkRepositoryPort
# Rôle : contrat de résolution d'un jeton de lien d'invitation /i/<jeton> (collègue, direction, équipe)
# ADR  : 0063, 0082
module Ports
  module Identity
    module InviteLinkRepositoryPort
      # channel ∈ colleague direction team ; referrer_id : le collègue (colleague seulement), sinon nil.
      # school_id : école principale du collègue ou établissement du jeton (nil : le collègue n'a plus d'école) ;
      # school_active : cet établissement est actif.
      InviteLink = Data.define(:school_id, :school_active, :channel, :referrer_id) do
        def valid? = school_id.present? && school_active == true
      end

      # Cherche le collègue d'abord, puis la direction, puis l'équipe (ADR-0082 §5). L'appelant juge avec valid?.
      # → InviteLink | nil (jeton inconnu)
      def resolve(token:)
        raise NotImplementedError, "#{self.class} doit implémenter #resolve"
      end
    end
  end
end
