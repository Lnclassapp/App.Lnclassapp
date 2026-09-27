# 🧠 DOMAINE · Dtos::Classroom::JoinWithCodeInput
# Rôle : forme de l'inscription d'un élève par le code de sa classe ; aucun rôle saisi, PIN toujours exigé
# ADR  : 0026, 0037, 0040, 0050 · UDR : 0009
module Dtos
  module Classroom
    class JoinWithCodeInput < Identity::PersonNameInput
      attribute :gender, :string
      attribute :contact, :string
      attribute :pin, :string
      attribute :pin_confirmation, :string

      attr_reader :raw_contact

      validates :gender, inclusion: { in: Entities::Identity::User::GENDERS }
      validates :pin, presence: true, format: { with: Entities::Identity::Pin::FORMAT, allow_blank: true }
      validates :pin, confirmation: true
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
