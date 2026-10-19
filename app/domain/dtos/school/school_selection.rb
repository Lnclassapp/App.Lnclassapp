# 🧠 DOMAINE · Dtos::School::SchoolSelection
# Rôle : sélection d'une régénération de masse : les filtres de la liste « Établissements », ou un seul établissement
# ADR  : 0096 · UDR : 0104
module Dtos
  module School
    SchoolSelection = Data.define(:drena, :school_type, :cycle, :status, :search, :school) do
      # Les filtres que lit le scope de la liste (Orm::School.list_filtered) ; `school` est un public_id et les remplace.
      def filters = school ? {} : SchoolSelection::FILTERS.to_h { [ it, public_send(it) ] }

      # Une seule DRENA ou un seul établissement : la portée se lit dans la modale, pas de nombre à taper (UDR-0104).
      def scoped? = !drena.nil? || !school.nil?

      # Ce que le rapport garde (clés en texte, valeurs présentes seulement) ; from(to_h) rend la même sélection.
      def to_h = (school ? { "school" => school } : super.compact.transform_keys(&:to_s))
    end

    SchoolSelection::FILTERS = %i[drena school_type cycle status search].freeze
    SchoolSelection::SEARCH_MAX = 100

    # params : Hash (clés symboles ou textes), ou nil pour « tous les établissements ». Un blanc est nil ; ce qui n'est pas
    # un texte est ignoré ; la recherche est bornée (la liste ne trouverait rien au-delà).
    def SchoolSelection.from(params = nil)
      values = (params || {}).to_h.transform_keys(&:to_s)
      read = members.to_h { |key| [ key, (values[key.to_s].squish.presence if values[key.to_s].is_a?(String)) ] }
      read[:search] = read[:search]&.first(SchoolSelection::SEARCH_MAX)
      new(**read)
    end
  end
end
