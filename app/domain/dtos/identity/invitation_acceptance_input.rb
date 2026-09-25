# 🧠 DOMAINE · Dtos::Identity::InvitationAcceptanceInput
# Rôle : forme de l'acceptation d'une invitation : nom, prénom(s), genre et PIN ; le numéro vient de l'invitation
# ADR  : 0037, 0038, 0050 · UDR : 0019
module Dtos
  module Identity
    class InvitationAcceptanceInput < PersonNameInput
      attribute :gender, :string
      attribute :pin, :string
      attribute :pin_confirmation, :string

      validates :gender, inclusion: { in: Entities::Identity::User::GENDERS }
      validates :pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validates :pin, confirmation: true
    end
  end
end
