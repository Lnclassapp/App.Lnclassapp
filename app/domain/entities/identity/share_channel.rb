# 🧠 DOMAINE · Entities::Identity::ShareChannel
# Rôle : liste fermée des canaux d'un partage « Inviter un collègue »
# ADR  : 0063 · UDR : 0050
module Entities
  module Identity
    module ShareChannel
      ALL = %w[whatsapp sms copy native].freeze

      def self.valid?(channel) = ALL.include?(channel)
    end
  end
end
