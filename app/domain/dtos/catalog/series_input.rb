# 🧠 DOMAINE · Dtos::Catalog::SeriesInput
# Rôle : saisie d'une série (création et renommage) : nom obligatoire, 10 caractères au plus, espaces normalisés
# ADR  : 0026, 0034
module Dtos
  module Catalog
    class SeriesInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :name, :string

      validates :name, presence: true, length: { maximum: Entities::Catalog::Series::NAME_MAX }

      def name
        super.to_s.squish
      end
    end
  end
end
