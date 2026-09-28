# 🧠 DOMAINE · Dtos::Identity::ContactChangeInput
# Rôle : forme du changement de numéro : PIN actuel, nouveau numéro et sa confirmation, normalisés
# ADR  : 0050, 0055 · UDR : 0041
module Dtos
  module Identity
    class ContactChangeInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :current_pin, :string
      attribute :contact, :string
      attribute :contact_confirmation, :string
      attribute :ip, :string
      attribute :user_agent, :string

      # La saisie telle quelle, re-affichée après un refus : un numéro hors format se normalise en nil.
      attr_reader :raw_contact, :raw_contact_confirmation

      validates :current_pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validate :contact_given
      validate :contact_confirmed

      def contact=(raw)
        @raw_contact = raw.to_s
        super(Entities::Identity::Contact.normalize(raw))
      end

      def contact_confirmation=(raw)
        @raw_contact_confirmation = raw.to_s
        super(Entities::Identity::Contact.normalize(raw))
      end

      private

      # Un numéro saisi mais hors format ne se dit pas « obligatoire ».
      def contact_given
        return unless contact.nil?

        errors.add(:contact, raw_contact.blank? ? :blank : :invalid)
      end

      # « 07 11 22 33 44 » confirme « 0711223344 » ; un numéro déjà refusé n'a pas d'erreur de confirmation en plus.
      def contact_confirmed
        return if contact.nil? || contact_confirmation == contact

        errors.add(:contact_confirmation, :confirmation)
      end
    end
  end
end
