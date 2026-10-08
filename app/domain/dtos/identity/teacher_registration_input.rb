# 🧠 DOMAINE · Dtos::Identity::TeacherRegistrationInput
# Rôle : forme de l'inscription enseignant : nom et prénoms (ADR-0037), établissement de la DRENA ou d'un jeton d'invitation
# ADR  : 0026, 0030, 0037, 0050, 0063, 0083 · UDR : 0024, 0079
module Dtos
  module Identity
    class TeacherRegistrationInput < PersonNameInput
      # Identifiants publics (ADR-0029) : toute autre forme (octet nul, espaces…) est oubliée avant la base.
      PUBLIC_ID = /\A[\w-]{1,64}\z/

      attribute :gender, :string
      attribute :contact, :string
      attribute :pin, :string
      attribute :pin_confirmation, :string
      attribute :drena_public_id, :string
      attribute :school_public_id, :string
      attribute :material_slug, :string
      # Jeton d'un lien /i/<jeton> (ADR-0083 §4.1), porté par un champ caché ; mal formé, il est oublié.
      attribute :invite_token, :string

      attr_reader :raw_contact

      validates :gender, inclusion: { in: Entities::Identity::User::GENDERS }
      validates :pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validates :pin, confirmation: true
      validates :material_slug, presence: true
      validate :contact_given
      validate :school_designated

      def contact=(raw)
        @raw_contact = raw.to_s
        super(Entities::Identity::Contact.normalize(raw))
      end

      def invite_token=(raw)
        super(Entities::Identity::ReferralToken.normalize(raw))
      end

      def drena_public_id = public_id_or_nil(super)
      def school_public_id = public_id_or_nil(super)

      private

      def public_id_or_nil(value) = (value if PUBLIC_ID.match?(value.to_s))

      # Un numéro saisi mais hors format ne se dit pas « obligatoire ».
      def contact_given
        return unless contact.nil?

        errors.add(:contact, raw_contact.blank? ? :blank : :invalid)
      end

      # Avec un jeton, l'établissement vient du lien et le use case le juge.
      def school_designated
        return if invite_token

        errors.add(:drena_public_id, :blank) if drena_public_id.blank?
        errors.add(:school_public_id, :blank) if school_public_id.blank?
      end
    end
  end
end
