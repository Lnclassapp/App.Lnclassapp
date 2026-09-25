# 🧠 DOMAINE · Dtos::Identity::TeacherRegistrationInput
# Rôle : forme de l'inscription enseignant ; aucun rôle saisi, la DRENA ne sert qu'à vérifier l'établissement
# ADR  : 0026, 0030, 0037, 0050 · UDR : 0024
module Dtos
  module Identity
    class TeacherRegistrationInput < PersonNameInput
      attribute :gender, :string
      attribute :contact, :string
      attribute :pin, :string
      attribute :pin_confirmation, :string
      attribute :drena_public_id, :string
      attribute :school_public_id, :string
      attribute :material_slug, :string

      attr_reader :raw_contact

      validates :gender, inclusion: { in: Entities::Identity::User::GENDERS }
      validates :pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validates :pin, confirmation: true
      validates :drena_public_id, :school_public_id, :material_slug, presence: true
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
