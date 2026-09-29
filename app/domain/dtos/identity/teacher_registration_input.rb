# 🧠 DOMAINE · Dtos::Identity::TeacherRegistrationInput
# Rôle : forme de l'inscription enseignant ; aucun rôle saisi, l'établissement est désigné par son code, jamais choisi
# ADR  : 0026, 0030, 0037, 0050, 0057, 0063 · UDR : 0024, 0044, 0050
module Dtos
  module Identity
    class TeacherRegistrationInput < PersonNameInput
      attribute :gender, :string
      attribute :contact, :string
      attribute :pin, :string
      attribute :pin_confirmation, :string
      attribute :school_code, :string
      attribute :material_slug, :string
      # Jeton du parrain (ADR-0063), porté par le lien /e/<code>?ref= puis par un champ caché ; mal formé, il est oublié.
      attribute :ref, :string

      attr_reader :raw_contact, :raw_school_code

      validates :gender, inclusion: { in: Entities::Identity::User::GENDERS }
      validates :pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validates :pin, confirmation: true
      validates :material_slug, presence: true
      validate :contact_given
      validate :school_code_well_formed

      def contact=(raw)
        @raw_contact = raw.to_s
        super(Entities::Identity::Contact.normalize(raw))
      end

      # « k7m 4QZ » → « k7m4qz » ; la saisie brute reste pour le re-rendu.
      def school_code=(raw)
        @raw_school_code = raw.to_s
        super(Entities::School::SchoolCode.normalize(raw))
      end

      def ref=(raw)
        super(Entities::Identity::ReferralToken.normalize(raw))
      end

      private

      # Un numéro saisi mais hors format ne se dit pas « obligatoire ».
      def contact_given
        return unless contact.nil?

        errors.add(:contact, raw_contact.blank? ? :blank : :invalid)
      end

      # La forme seule, sans recherche : un code de classe saisi par erreur a son message (ADR-0057).
      def school_code_well_formed
        return errors.add(:school_code, :blank) if school_code.blank?
        return if Entities::School::SchoolCode.valid?(school_code)

        errors.add(:school_code, Entities::School::SchoolCode.classroom_code?(school_code) ? :classroom_code : :invalid)
      end
    end
  end
end
