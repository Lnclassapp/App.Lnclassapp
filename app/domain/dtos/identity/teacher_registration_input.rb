# 🧠 DOMAINE · Dtos::Identity::TeacherRegistrationInput
# Rôle : forme de l'inscription enseignant : nom complet découpé (ou corrigé), établissement de la DRENA ou d'un jeton d'invitation
# ADR  : 0026, 0030, 0037, 0050, 0063, 0082 · UDR : 0024, 0078
module Dtos
  module Identity
    class TeacherRegistrationInput < PersonNameInput
      # Identifiants publics (ADR-0029) : toute autre forme (octet nul, espaces…) est oubliée avant la base.
      PUBLIC_ID = /\A[\w-]{1,64}\z/

      attribute :full_name, :string
      attribute :gender, :string
      attribute :contact, :string
      attribute :pin, :string
      attribute :pin_confirmation, :string
      attribute :drena_public_id, :string
      attribute :school_public_id, :string
      attribute :material_slug, :string
      # Jeton d'un lien /i/<jeton> (ADR-0082 §4.1), porté par un champ caché ; mal formé, il est oublié.
      attribute :invite_token, :string

      attr_reader :raw_contact

      validates :gender, inclusion: { in: Entities::Identity::User::GENDERS }
      validates :pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validates :pin, confirmation: true
      validates :material_slug, presence: true
      validate :contact_given
      # Après les règles de l'ADR-0037 (PersonNameInput) : quand le serveur a découpé, leurs erreurs vont sous « Nom complet ».
      validate :full_name_split
      validate :school_designated

      def full_name = super&.squish

      # « Corriger » (UDR-0078 §3.3) : le nom et les prénoms, tous deux remplis, font foi.
      def corrected? = raw_last_name.present? && raw_first_name.present?

      def last_name = corrected? ? super : split&.first
      def first_name = corrected? ? super : split&.last

      # Les deux champs de correction tels que saisis, pour le re-rendu : jamais le découpage.
      def raw_last_name = @attributes.fetch_value("last_name")
      def raw_first_name = @attributes.fetch_value("first_name")

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

      def split = Entities::Identity::FullName.split(full_name)
      def public_id_or_nil(value) = (value if PUBLIC_ID.match?(value.to_s))

      # Un numéro saisi mais hors format ne se dit pas « obligatoire ».
      def contact_given
        return unless contact.nil?

        errors.add(:contact, raw_contact.blank? ? :blank : :invalid)
      end

      # Découpé par le serveur, le nom n'a qu'un champ : ses erreurs vont sous « Nom complet », un seul mot compris.
      def full_name_split
        return if corrected?

        moved = errors.select { %i[last_name first_name].include?(it.attribute) }
        moved.map(&:attribute).uniq.each { errors.delete(it) }
        return errors.add(:full_name, full_name.blank? ? :blank : :single_word) if split.nil?

        moved.each { errors.import(it, attribute: :full_name) }
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
