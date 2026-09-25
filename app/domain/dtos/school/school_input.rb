# 🧠 DOMAINE · Dtos::School::SchoolInput
# Rôle : modification d'un établissement : DRENA, nom (150), sigle (15), type, statut et cycle ; jamais de création
# ADR  : 0030, 0036 · UDR : 0036
module Dtos
  module School
    class SchoolInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :drena_public_id, :string
      attribute :name, :string
      attribute :sigle, :string
      attribute :school_type, :string
      attribute :status, :string
      attribute :cycle, :string

      validates :drena_public_id, presence: true
      validates :name, presence: true, length: { maximum: Entities::School::School::NAME_MAX }
      validates :sigle, length: { maximum: Entities::School::School::SIGLE_MAX }
      validates :school_type, inclusion: { in: Entities::School::School::SCHOOL_TYPES }
      validates :status, inclusion: { in: Entities::School::School::STATUSES }
      validates :cycle, inclusion: { in: Entities::School::School::CYCLES }

      def name = super.to_s.squish
      def sigle = super.to_s.squish.presence

      # La DRENA reste à part : le use case la résout par son public_id avant de construire l'entité.
      def to_h = { name:, sigle:, school_type:, status:, cycle: }
    end
  end
end
