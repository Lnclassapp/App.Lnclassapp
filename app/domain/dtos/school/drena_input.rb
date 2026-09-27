# 🧠 DOMAINE · Dtos::School::DrenaInput
# Rôle : forme du nom d'une DRENA saisi à l'écran : obligatoire, 80 caractères au plus, espaces normalisés, casse intacte
# ADR  : 0026, 0034
module Dtos
  module School
    class DrenaInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :name, :string

      validates :name, presence: true, length: { maximum: Entities::School::Drena::NAME_MAX }

      # Un nom fait d'espaces n'est pas un nom : il devient nil.
      def name
        super.to_s.squish.presence
      end
    end
  end
end
