# 🧠 DOMAINE · Dtos::Catalog::MaterialInput
# Rôle : saisie d'une matière : nom (40), abrégé (10) et catégorie obligatoire ; espaces resserrés, casse gardée
# ADR  : 0034 · UDR : 0034
module Dtos
  module Catalog
    class MaterialInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :name, :string
      attribute :shortname, :string
      attribute :category, :string

      validates :name, presence: true, length: { maximum: Entities::Catalog::Material::NAME_MAX }
      validates :shortname, presence: true, length: { maximum: Entities::Catalog::Material::SHORTNAME_MAX }
      # Aucune catégorie par défaut : c'est elle, jamais le nom, qui donne sa couleur et son icône à la matière.
      validates :category, inclusion: { in: Entities::Catalog::Material::CATEGORIES }

      def name = super.to_s.squish
      def shortname = super.to_s.squish
      def to_h = { name:, shortname:, category: }
    end
  end
end
