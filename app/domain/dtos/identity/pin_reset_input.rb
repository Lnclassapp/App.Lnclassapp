# 🧠 DOMAINE · Dtos::Identity::PinResetInput
# Rôle : forme de la réinitialisation du PIN par code de récupération
# ADR  : 0032, 0050
module Dtos
  module Identity
    class PinResetInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      CODE_FORMAT = /\A\d{#{Entities::Identity::PinRecoveryCode::LENGTH}}\z/

      attribute :contact, :string
      attribute :code, :string
      attribute :pin, :string
      attribute :pin_confirmation, :string
      attribute :ip, :string

      validates :contact, presence: true
      validates :code, presence: true, format: { with: CODE_FORMAT, allow_blank: true }
      validates :pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validates :pin, confirmation: true

      def contact=(raw)
        super(Entities::Identity::Contact.normalize(raw))
      end

      def code = super&.gsub(/\s/, "")
    end
  end
end
