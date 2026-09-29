# 🧠 DOMAINE · Entities::School::Drena
# Rôle : direction régionale de l'éducation, créée à l'écran ou importée ; son slug figé, préfixé drena-, cible les imports d'écoles
# ADR  : 0029, 0034, 0039, 0055
module Entities
  module School
    class Drena
      include ActiveModel::Model

      NAME_MAX = 80
      SLUG_PREFIX = "drena"

      attr_accessor :id, :public_id, :slug
      attr_reader :name

      validates :name, presence: true, length: { maximum: NAME_MAX }

      def name=(value)
        @name = value&.squish
      end

      # Seule règle du slug, au formulaire comme à l'import : « Bouaké 1 » → « drena-bouake-1 ».
      # nil pour un nom sans lettre ni chiffre latin, qui ne distinguerait pas la DRENA.
      def self.slug_for(name)
        base = name.to_s.parameterize
        "#{SLUG_PREFIX}-#{base}" if base.present?
      end

      # Clé de résolution d'un import : le slug figé, ou celui que donnerait le nom.
      def key = slug.presence || self.class.slug_for(name)
    end
  end
end
