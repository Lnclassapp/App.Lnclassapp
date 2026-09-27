# 🧠 DOMAINE · Dtos::Identity::SecondFactorCodeInput
# Rôle : code TOTP à 6 chiffres ou code de secours à 10 caractères base58
# ADR  : 0031
module Dtos
  module Identity
    class SecondFactorCodeInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      TOTP_FORMAT = /\A\d{6}\z/
      BACKUP_FORMAT = /\A[1-9A-HJ-NP-Za-km-z]{#{Entities::Identity::BackupCodes::LENGTH}}\z/

      attribute :code, :string

      validates :code, presence: true
      validate :code_format, if: -> { code.present? }

      def code
        super&.gsub(/\s/, "")
      end

      def totp? = code.to_s.match?(TOTP_FORMAT)
      def backup_code? = code.to_s.match?(BACKUP_FORMAT)

      private

      def code_format
        errors.add(:code, :invalid) unless totp? || backup_code?
      end
    end
  end
end
