# 🧠 DOMAINE · Dtos::Identity::SchoolStaffInvitationInput
# Rôle : forme d'une invitation de direction : le numéro de la personne invitée, pour l'établissement de la fiche
# ADR  : 0038, 0050, 0065 · UDR : 0019, 0052
module Dtos
  module Identity
    class SchoolStaffInvitationInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :contact, :string
      # Tiré de l'adresse de la fiche par le contrôleur, jamais du formulaire.
      attribute :school_public_id, :string

      attr_reader :raw_contact

      # Porte l'erreur school: [:inactive] du use case (ADR-0065), dite en tête de la modale.
      def school = school_public_id

      validate :contact_given

      def contact=(raw)
        @raw_contact = raw.to_s
        super(Entities::Identity::Contact.normalize(raw))
      end

      private

      # Un numéro saisi mais hors format ne se dit pas « obligatoire ».
      def contact_given
        return unless contact.nil?

        errors.add(:contact, raw_contact.blank? ? :blank : :invalid)
      end
    end
  end
end
