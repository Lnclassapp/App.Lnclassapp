# 🧠 DOMAINE · Dtos::School::DrenaInput
# Rôle : forme du nom d'une DRENA saisi à l'écran : obligatoire, 80 caractères au plus, avec une lettre ou un chiffre latin
# ADR  : 0026, 0034, 0066
module Dtos
  module School
    class DrenaInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :name, :string

      validates :name, presence: true, length: { maximum: Entities::School::Drena::NAME_MAX }
      validate :name_gives_a_slug

      # Un nom fait d'espaces n'est pas un nom : il devient nil.
      def name
        super.to_s.squish.presence
      end

      private

      # Sans lettre ni chiffre latin (« ??? »), le slug serait « drena » nu : Drena.slug_for rend nil.
      def name_gives_a_slug
        errors.add(:name, :invalid) if name && Entities::School::Drena.slug_for(name).nil?
      end
    end
  end
end
