# 🧠 DOMAINE · Dtos::Identity::TeamInvitationInput
# Rôle : forme d'une invitation dans l'équipe : le numéro de la personne invitée et son rôle
# ADR  : 0026, 0038, 0050 · UDR : 0019
module Dtos
  module Identity
    class TeamInvitationInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :contact, :string
      attribute :team_role, :string

      attr_reader :raw_contact

      validates :team_role, inclusion: { in: Entities::Identity::User::TEAM_ROLES }
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
