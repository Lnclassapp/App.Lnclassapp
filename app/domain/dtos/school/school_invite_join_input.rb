# 🧠 DOMAINE · Dtos::School::SchoolInviteJoinInput
# Rôle : le jeton d'un lien /i/<jeton> ouvert par un enseignant connecté, qui confirme « Rejoindre l'établissement »
# ADR  : 0083, 0094 · UDR : 0099 (§3.4)
module Dtos
  module School
    class SchoolInviteJoinInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Les jetons sont 12 caractères hexadécimaux (ADR-0063, 0083) : toute autre forme est oubliée avant la base.
      TOKEN = /\A[0-9a-f]{12}\z/

      attribute :token, :string

      validates :token, presence: true

      def token = (super if TOKEN.match?(super.to_s))
      def to_h = { token: }
    end
  end
end
