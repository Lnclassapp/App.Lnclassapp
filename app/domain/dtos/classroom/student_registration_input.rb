# 🧠 DOMAINE · Dtos::Classroom::StudentRegistrationInput
# Rôle : forme de l'inscription élève : nom complet découpé (ou corrigé), classe choisie dans la cascade ou donnée par le jeton d'un lien
# ADR  : 0026, 0037, 0050, 0083, 0085 · UDR : 0081
module Dtos
  module Classroom
    class StudentRegistrationInput < Identity::PersonNameInput
      # Identifiants publics et slugs (ADR-0029) : toute autre forme (octet nul, espaces…) est oubliée avant la base.
      PUBLIC_ID = /\A[\w-]{1,64}\z/
      # Jeton d'un lien /c/<jeton> (ADR-0085 §4.1) : la forme des jetons de l'ADR-0083, 12 caractères hexadécimaux.
      LINK_TOKEN = /\A[0-9a-f]{12}\z/

      attribute :full_name, :string
      attribute :gender, :string
      attribute :contact, :string
      attribute :pin, :string
      attribute :pin_confirmation, :string
      attribute :drena_public_id, :string
      attribute :school_public_id, :string
      attribute :level_slug, :string
      attribute :classroom_public_id, :string
      # Porté par un champ caché, seulement quand la classe vient d'un lien ; mal formé, il est oublié.
      attribute :link_token, :string

      attr_reader :raw_contact

      validates :gender, inclusion: { in: Entities::Identity::User::GENDERS }
      validates :pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validates :pin, confirmation: true
      validate :contact_given
      # Après les règles de l'ADR-0037 (PersonNameInput) : quand le serveur a découpé, leurs erreurs vont sous « Nom complet ».
      validate :full_name_split
      validate :classroom_designated

      # « 0A1B… » recopié → « 0a1b… » ; un ancien code de classe (5 caractères) ou toute autre forme → nil, sans recherche.
      def self.normalize_link_token(raw)
        token = raw.to_s.strip.downcase
        token if LINK_TOKEN.match?(token)
      end

      def full_name = super&.squish

      # « Corriger » (UDR-0081 §3.2, UDR-0079 §3.3) : le nom et les prénoms, tous deux remplis, font foi.
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

      def link_token=(raw)
        super(self.class.normalize_link_token(raw))
      end

      def drena_public_id = public_id_or_nil(super)
      def school_public_id = public_id_or_nil(super)
      def level_slug = public_id_or_nil(super)
      def classroom_public_id = public_id_or_nil(super)

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

      # Avec un jeton, la classe vient du lien et le use case le juge ; sans lui, la classe choisie est exigée. La DRENA,
      # l'établissement et le niveau sont jugés par le use case, avec la classe (ADR-0085 §4.2).
      def classroom_designated
        return if link_token

        errors.add(:classroom_public_id, :blank) if classroom_public_id.blank?
      end
    end
  end
end
