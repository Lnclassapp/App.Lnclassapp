# 🧠 DOMAINE · Entities::School::Drena
# Rôle : direction régionale de l'éducation, créée à l'écran par l'équipe ; son slug figé cible les imports d'écoles
# ADR  : 0029, 0034, 0039
module Entities
  module School
    class Drena
      include ActiveModel::Model

      NAME_MAX = 80

      attr_accessor :id, :public_id, :slug
      attr_reader :name

      validates :name, presence: true, length: { maximum: NAME_MAX }

      def name=(value)
        @name = value&.squish
      end

      # Clé de résolution d'un import : le slug figé, ou celui que donnerait le nom.
      def key = slug.presence || name.to_s.parameterize
    end
  end
end
