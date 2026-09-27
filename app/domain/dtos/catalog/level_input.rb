# 🧠 DOMAINE · Dtos::Catalog::LevelInput
# Rôle : forme d'un niveau saisi par l'équipe : nom de 20 caractères au plus, position entière, cycle connu
# ADR  : 0026, 0034
module Dtos
  module Catalog
    class LevelInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Borne de forme : au-delà, la colonne integer refuserait la valeur. Le signe est une règle de l'entité.
      POSITION_MAX = 999

      attribute :name, :string
      # Gardée telle que saisie : un texte ne devient pas zéro, et la modale en 422 le réaffiche.
      attribute :position, :string
      attribute :cycle, :string

      validates :name, presence: true, length: { maximum: Entities::Catalog::Level::NAME_MAX }
      validates :position, numericality: { only_integer: true, less_than_or_equal_to: POSITION_MAX }
      validates :cycle, inclusion: { in: Entities::Catalog::Level::CYCLES }

      def name
        super&.squish
      end

      # Appelé sur une saisie valide : la position est alors un entier écrit en chiffres.
      def level_attributes = { name:, position: Integer(position, 10), cycle: }
    end
  end
end
