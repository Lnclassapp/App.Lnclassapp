# 🧠 DOMAINE · Dtos::Identity::CredentialsInput
# Rôle : forme de la saisie de connexion ; le contact est normalisé à l'affectation
# ADR  : 0050
module Dtos
  module Identity
    class CredentialsInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :contact, :string
      attribute :pin, :string
      attribute :ip, :string
      attribute :user_agent, :string

      attr_reader :raw_contact

      validates :contact, presence: true
      validates :pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }

      def contact=(raw)
        @raw_contact = raw.to_s
        super(Entities::Identity::Contact.normalize(raw))
      end

      # Clé du verrouillage : le numéro normalisé si possible, brut sinon (ADR-0050).
      def attempt_key = contact || raw_contact.to_s.first(20)
    end
  end
end
