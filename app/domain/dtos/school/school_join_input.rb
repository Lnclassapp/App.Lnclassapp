# 🧠 DOMAINE · Dtos::School::SchoolJoinInput
# Rôle : DRENA puis établissement choisis sur l'écran d'attente par un enseignant sans établissement (plus de code)
# ADR  : 0071, 0083 · UDR : 0079
module Dtos
  module School
    class SchoolJoinInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Identifiants publics (ADR-0029) : toute autre forme (octet nul, espaces…) est oubliée avant la base.
      PUBLIC_ID = /\A[\w-]{1,64}\z/

      attribute :drena_public_id, :string
      attribute :school_public_id, :string

      validates :drena_public_id, :school_public_id, presence: true

      def drena_public_id = public_id_or_nil(super)
      def school_public_id = public_id_or_nil(super)
      def to_h = { drena_public_id:, school_public_id: }

      private

      def public_id_or_nil(value) = (value if PUBLIC_ID.match?(value.to_s))
    end
  end
end
