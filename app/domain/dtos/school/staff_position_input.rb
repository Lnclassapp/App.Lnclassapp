# 🧠 DOMAINE · Dtos::School::StaffPositionInput
# Rôle : forme du changement de fonction d'une direction par l'équipe : une des quatre fonctions
# ADR  : 0092 · UDR : 0092 (§3.4)
module Dtos
  module School
    class StaffPositionInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :position, :string

      validate :position_chosen

      private

      def position_chosen
        errors.add(:position, :blank) unless Entities::School::StaffPosition.valid?(position)
      end
    end
  end
end
