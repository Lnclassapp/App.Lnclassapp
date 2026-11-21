# 🧠 DOMAINE · Dtos::Identity::StudentEntryInput
# Rôle : forme de l'entrée élève unique : numéro et code secret, puis la confirmation du code quand le numéro n'a pas de compte
# ADR  : 0050, 0141-entree-eleve-revele-un-numero-inscrit · UDR : 0176-entree-eleve-unique
module Dtos
  module Identity
    class StudentEntryInput < CredentialsInput
      # nil au premier envoi ; posée par l'écran « Ce numéro n'a pas encore de compte ».
      attribute :pin_confirmation, :string

      # Un numéro hors format ne se dit pas « obligatoire » ; il n'est jamais cherché.
      validate :contact_given, :pin_confirmation_shape

      def confirming? = !pin_confirmation.nil?

      private

      def contact_given
        return unless contact.nil?

        errors.delete(:contact)
        errors.add(:contact, raw_contact.blank? ? :blank : :invalid)
      end

      def pin_confirmation_shape
        errors.add(:pin_confirmation, :blank) if confirming? && pin_confirmation.blank?
      end
    end
  end
end
