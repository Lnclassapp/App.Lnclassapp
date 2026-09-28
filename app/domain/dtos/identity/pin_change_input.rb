# 🧠 DOMAINE · Dtos::Identity::PinChangeInput
# Rôle : forme du changement de son PIN : PIN actuel, nouveau PIN et sa confirmation (ADR-0025)
# ADR  : 0025, 0050, 0055
module Dtos
  module Identity
    class PinChangeInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :current_pin, :string
      attribute :pin, :string
      attribute :pin_confirmation, :string
      attribute :ip, :string
      attribute :user_agent, :string

      validates :current_pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validates :pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validates :pin, confirmation: true
    end
  end
end
