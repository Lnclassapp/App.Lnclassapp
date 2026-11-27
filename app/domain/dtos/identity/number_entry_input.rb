# 🧠 DOMAINE · Dtos::Identity::NumberEntryInput
# Rôle : forme de l'entrée « numéro d'abord » (/login, /student) : le numéro seul (code absent, nil) pour savoir s'il a un compte, puis le code
# ADR  : 0050, 0141-entree-eleve-revele-un-numero-inscrit, 0148-connexion-revele-un-numero-inscrit · UDR : 0189-connexion-numero-d-abord
module Dtos
  module Identity
    class NumberEntryInput < CredentialsInput
      # Un numéro hors format ne se dit pas « obligatoire » ; il n'est jamais cherché. Le code absent (nil, pas "") : le numéro seul.
      validate :contact_given, :pin_optional_for_lookup

      def lookup? = pin.nil?

      private

      def contact_given
        return unless contact.nil?

        errors.delete(:contact)
        errors.add(:contact, raw_contact.blank? ? :blank : :invalid)
      end

      def pin_optional_for_lookup
        errors.delete(:pin) if lookup?
      end
    end
  end
end
