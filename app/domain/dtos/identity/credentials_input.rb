# 🧠 DOMAINE · Dtos::Identity::CredentialsInput
# Rôle : forme de la saisie de connexion ; le contact est normalisé à l'affectation ; client : le site ou l'une des deux coques
# ADR  : 0050, 0084 (§4.5), 0086 (§4.5)
module Dtos
  module Identity
    class CredentialsInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Chaque coque Android reconnue par le contrôleur n'admet qu'un rôle (ADR-0086 §4.1, §4.5) ; le site les admet tous.
      ROLE_FOR_CLIENT = { "android_student" => "student", "android_teacher" => "teacher" }.freeze
      CLIENTS = [ "web", *ROLE_FOR_CLIENT.keys ].freeze

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

      def admits?(role) = ROLE_FOR_CLIENT.fetch(client, role) == role
    end
  end
end
