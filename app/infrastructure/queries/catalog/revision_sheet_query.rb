# 🔌 INFRA · Queries::Catalog::RevisionSheetQuery
# Rôle : la « Fiche de révision » d'une leçon pour sa page (fiche cahier, ou texte de la leçon puis des notions), coupée après 150 mots ; squelette du Lot 0
# ADR  : 0110-fiche-de-cours-en-donnees-importees, 0113 · UDR : 0139 §3.2
module Queries
  module Catalog
    class RevisionSheetQuery
      # kind : :sheet (fiche cahier), :texts (texte de la leçon puis notions) ou :empty ; sheet : CourseSheetQuery::Row | nil ;
      # texts : [{ title:, html: }] ; cut : la coupe des 150 mots (Entities::Catalog::RevisionPreview), nil sans coupe.
      # Contrat gelé par le Lot 0 : le Lot A le remplit, sans le changer.
      Revision = Data.define(:kind, :sheet, :texts, :cut)

      EMPTY = Revision.new(kind: :empty, sheet: nil, texts: [], cut: nil)

      # → Revision. Squelette : toujours :empty (le Lot A le complète).
      def call(course_slug:, actor:) = EMPTY
    end
  end
end
