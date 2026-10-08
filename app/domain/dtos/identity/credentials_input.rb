# 🧠 DOMAINE · Dtos::Identity::CredentialsInput
# Rôle : forme de la saisie de connexion ; le contact est normalisé à l'affectation ; client : site ou coque élèves
# ADR  : 0050, 0084 (§4.5)
module Dtos
  module Identity
    class CredentialsInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Le site, ou la coque Android des élèves reconnue par le contrôleur (ADR-0084 §4.1).
      CLIENTS = %w[web android_student].freeze

      attribute :contact, :string
      attribute :pin, :string
      attribute :ip, :string
      attribute :user_agent, :string
      attribute :client, :string, default: "web"

      attr_reader :raw_contact

      validates :contact, presence: true
      validates :pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validates :client, inclusion: { in: CLIENTS }

      def contact=(raw)
        @raw_contact = raw.to_s
        super(Entities::Identity::Contact.normalize(raw))
      end

      # Clé du verrouillage : le numéro normalisé si possible, brut sinon (ADR-0050).
      def attempt_key = contact || raw_contact.to_s.first(20)

      def student_app? = client == "android_student"
    end
  end
end
