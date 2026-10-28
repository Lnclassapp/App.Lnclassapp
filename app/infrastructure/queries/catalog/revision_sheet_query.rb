# 🔌 INFRA · Queries::Catalog::RevisionSheetQuery
# Rôle : la « Fiche de révision » d'une leçon pour sa page (fiche cahier, ou texte de la leçon puis des notions publiées), avec sa coupe des 150 mots
# ADR  : 0110-fiche-de-cours-en-donnees-importees, 0113 · UDR : 0139 §3.2
module Queries
  module Catalog
    class RevisionSheetQuery
      # kind : :sheet (fiche cahier), :texts (texte de la leçon puis notions) ou :empty ; sheet : CourseSheetQuery::Row | nil ;
      # texts : [{ title:, html:, blocks: }] (title nil pour le texte de la leçon ; html : le texte entier, blocks : son html
      # bloc par bloc, dans l'ordre) ; cut : la coupe des 150 mots (Entities::Catalog::RevisionPreview), nil sans coupe.
      # Contrat gelé par le Lot 0 : le Lot A le remplit, sans le changer (`blocks` complète l'élément de `texts`).
      Revision = Data.define(:kind, :sheet, :texts, :cut)

      EMPTY = Revision.new(kind: :empty, sheet: nil, texts: [], cut: nil)

      # → Revision. Les brouillons et archivés ne figurent jamais ici : la fiche se lit publiée, pour tous les rôles.
      def call(course_slug:, actor:) # rubocop:disable Lint/UnusedMethodArgument -- signature gelée par le Lot 0
        sheet = CourseSheetQuery.new.call(course_slug:)
        return sheet_revision(sheet) if sheet

        course = Orm::Course.find_by(slug: course_slug)
        course ? texts_revision(course) : EMPTY
      end

      private

      def sheet_revision(sheet)
        preview = Entities::Catalog::RevisionPreview.for_sheet(sheet.pages)
        Revision.new(kind: :sheet, sheet:, texts: [], cut: (preview if preview.cut?))
      end

      def texts_revision(course)
        texts = [ text_entry(nil, course.content) ] + essential_entries(course.id)
        texts.select! { it[:blocks].any? }
        return EMPTY if texts.empty?

        preview = Entities::Catalog::RevisionPreview.for_texts(texts.map { { title: it[:title], blocks: it[:plain] } })
        Revision.new(kind: :texts, sheet: nil, texts: texts.map { it.except(:plain) }, cut: (preview if preview.cut?))
      end

      # Les notions publiées dans l'ordre, leurs textes lus d'une seule requête (pas de préchargement : Bullet le juge inutile
      # quand une notion n'a pas de texte).
      def essential_entries(course_id)
        rows = Orm::Essential.where(course_id:, status: "published").order(:position).pluck(:id, :name)
        bodies = ActionText::RichText.where(record_type: "Orm::Essential", record_id: rows.map(&:first), name: "content")
                                     .index_by(&:record_id)
        rows.map { |id, name| text_entry(name, bodies[id]) }
      end

      # Le texte rendu et assaini par Action Text, coupé en blocs de premier niveau (un paragraphe = un bloc). plain : le texte
      # de chaque bloc pour le compte des mots ; une figure (image jointe) n'en porte aucun.
      def text_entry(title, rich_text)
        nodes = rich_text.blank? ? [] : blocks_of(rich_text.to_s)
        { title:, html: nodes.sum("".html_safe) { it.to_html.html_safe }, # rubocop:disable Rails/OutputSafety -- rendu et assaini par Action Text
          blocks: nodes.map { it.to_html.html_safe }, # rubocop:disable Rails/OutputSafety -- idem
          plain: nodes.map { it.name == "figure" ? "" : it.text } }
      end

      def blocks_of(html)
        fragment = Nokogiri::HTML5.fragment(html)
        (fragment.at_css("div.trix-content") || fragment).children.reject { it.text? && it.text.strip.empty? }
      end
    end
  end
end
