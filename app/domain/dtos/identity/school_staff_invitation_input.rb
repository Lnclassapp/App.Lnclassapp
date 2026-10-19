# 🧠 DOMAINE · Dtos::Identity::SchoolStaffInvitationInput
# Rôle : forme d'une invitation de direction : le numéro et la fonction de la personne invitée, pour l'établissement de la fiche
# ADR  : 0038, 0050, 0065, 0092 · UDR : 0019, 0052, 0092
module Dtos
  module Identity
    class SchoolStaffInvitationInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :contact, :string
      attribute :position, :string
      # Tiré de l'adresse de la fiche par le contrôleur, jamais du formulaire.
      attribute :school_public_id, :string

      attr_reader :raw_contact

      # Porte l'erreur school: [:inactive] du use case (ADR-0065), dite en tête de la modale.
      def school = school_public_id

      validate :contact_given
      validate :position_chosen

      def contact=(raw)
        @raw_contact = raw.to_s
        super(Entities::Identity::Contact.normalize(raw))
      end

      private

      # Une des quatre fonctions, obligatoire (ADR-0092, réponse DIR-4 du porteur).
      def position_chosen
        errors.add(:position, :blank) unless Entities::School::StaffPosition.valid?(position)
      end

      # Un numéro saisi mais hors format ne se dit pas « obligatoire ».
      def contact_given
        return unless contact.nil?

        errors.add(:contact, raw_contact.blank? ? :blank : :invalid)
      end
    end
  end
end
