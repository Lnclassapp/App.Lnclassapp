# 🧠 DOMAINE · Entities::School::StaffPosition
# Rôle : les quatre fonctions de direction (liste fermée), leur rang de droits et la clé de leur libellé
# ADR  : 0092 (§4.1, §4.3)
module Entities
  module School
    module StaffPosition
      HEAD = "head".freeze
      ALL = %w[head deputy educator secretary].freeze
      MANAGEMENT = %w[head deputy].freeze
      PUBLIC = "public".freeze

      module_function

      def valid?(position) = ALL.include?(position)

      # Rang « gestion » : la structure, les enseignants, les directions. Une fonction absente ou inconnue n'y est pas :
      # depuis la réponse DIR-4 du porteur, toute direction a une fonction ; un acteur sans fonction n'a que les lectures.
      def management?(position) = MANAGEMENT.include?(position)

      # → :management | :school_life
      def rank(position) = management?(position) ? :management : :school_life

      # Clé de libellé (shared.staff_positions.<clé>) : « deputy » se lit selon le type d'établissement ; sans établissement
      # connu (inscription par le code), les deux libellés ensemble.
      def label_key(position, school_type: nil)
        return position unless position == "deputy"
        return "deputy_any" if school_type.nil?

        school_type == PUBLIC ? "deputy_public" : "deputy_private"
      end
    end
  end
end
