# 🔌 INFRA · Queries::School::CodeRegenerationPreviewQuery
# Rôle : ce que la modale d'une régénération de masse annonce : le nombre d'objets et la portée lisible (DRENA, établissement)
# ADR  : 0096 (§4.5 : mêmes scopes que les repositories) · UDR : 0104, 0105 · jamais un code ni un jeton
module Queries
  module School
    class CodeRegenerationPreviewQuery
      Kind = Entities::Catalog::ImportKind
      # drena_name, school_name : nil hors d'une DRENA ou d'un établissement, ou si le public_id ne désigne plus rien.
      Scope = Data.define(:drena_name, :school_name)
      Preview = Data.define(:target, :count, :scope, :school_year)

      # target : « school_codes » ou « classroom_links » ; selection : Dtos::School::SchoolSelection ;
      # school_year : celle des classes comptées, nil pour toutes les années (ignorée pour les codes). → Preview
      def call(target:, selection:, school_year:)
        school_year = nil if target == Kind::SCHOOL_CODE_REGENERATION
        Preview.new(target:, count: count(target, selection, school_year), scope: scope(selection), school_year:)
      end

      # Noms lisibles de la sélection, aussi pour le sous-titre du rapport. → Scope
      def scope(selection)
        Scope.new(drena_name: (Orm::Drena.where(public_id: selection.drena).pick(:name) if selection.drena && !selection.school),
                  school_name: (Orm::School.where(public_id: selection.school).pick(:name) if selection.school))
      end

      private

      def count(target, selection, school_year)
        return Orm::School.regeneration_selection(selection).count if target == Kind::SCHOOL_CODE_REGENERATION

        Orm::Classroom.link_regeneration(selection, school_year).count
      end
    end
  end
end
