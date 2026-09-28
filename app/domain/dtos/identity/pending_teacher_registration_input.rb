# 🧠 DOMAINE · Dtos::Identity::PendingTeacherRegistrationInput
# Rôle : inscription enseignant sans code : l'établissement est désigné par son code national, ou choisi dans sa DRENA
# ADR  : 0030, 0063 · UDR : 0024, 0050
module Dtos
  module Identity
    class PendingTeacherRegistrationInput < TeacherRegistrationInput
      attribute :national_code, :string
      attribute :drena_public_id, :string
      attribute :school_public_id, :string

      attr_reader :raw_national_code

      validate :school_designated

      # « 012 345 » → « 012345 » ; la saisie brute reste pour le re-rendu.
      def national_code=(raw)
        @raw_national_code = raw.to_s
        super(Entities::School::NationalCode.normalize(raw))
      end

      private

      # Le code d'établissement n'est pas demandé ici.
      def school_code_well_formed; end

      def school_designated
        if national_code
          errors.add(:national_code, :invalid) unless Entities::School::NationalCode.valid?(national_code)
        elsif school_public_id.blank?
          errors.add(:base, :school_missing)
        end
      end
    end
  end
end
