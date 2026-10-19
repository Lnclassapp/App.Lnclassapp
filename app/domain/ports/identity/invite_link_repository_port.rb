# 🧠 DOMAINE · Ports::Identity::InviteLinkRepositoryPort
# Rôle : contrat de résolution d'un jeton de lien d'invitation /i/<jeton> (collègue de l'établissement, parrainage, direction, équipe)
# ADR  : 0063, 0083, 0094 (§11)
module Ports
  module Identity
    module InviteLinkRepositoryPort
      # channel ∈ colleague direction team ; referrer_id : le collègue (colleague seulement), sinon nil — nil aussi pour un
      # parrainage dont le collègue est anonymisé. school_id : l'établissement du lien (nil : le collègue n'y est plus, ou
      # parrainage) ; school_active : cet établissement est actif. sponsor : le lien de parrainage, sans établissement
      # (ADR-0094 §11) : le collègue invité choisit le sien.
      InviteLink = Data.define(:school_id, :school_active, :channel, :referrer_id, :sponsor) do
        def initialize(school_id:, school_active:, channel:, referrer_id:, sponsor: false) = super

        def valid? = sponsor ? !referrer_id.nil? : (school_id.present? && school_active == true)
      end

      # Cherche le collègue (lien d'un établissement, puis parrainage) d'abord, puis la direction, puis l'équipe
      # (ADR-0083 §5). L'appelant juge avec valid?. → InviteLink | nil (jeton inconnu)
      def resolve(token:)
        raise NotImplementedError, "#{self.class} doit implémenter #resolve"
      end
    end
  end
end
