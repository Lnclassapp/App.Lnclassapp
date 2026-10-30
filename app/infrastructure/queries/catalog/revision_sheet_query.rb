# 🔌 INFRA · Queries::Catalog::RevisionSheetQuery
# Rôle : la « Fiche de révision » d'une leçon pour sa page : ses notions au gabarit des quatre blocs (et « Je m'entraîne » sans correction), ses figures et son thème, avec la coupe des 150 mots
# ADR  : 0116-fiche-de-revision-par-notion-et-figures-parametrees (§4.3), XXXX-entrainement-de-notion-corrige-sans-trace (§4) · UDR : 0141-fiche-de-revision-en-quatre-blocs §3.1, 0139 §3.2, XXXX-je-m-entraine-dans-la-fiche §3.1
module Queries
  module Catalog
    class RevisionSheetQuery
      # kind : :sheet (au moins une notion à montrer) ou :empty ; sheet : Lesson | nil ; cut : la coupe des 150 mots
      # (Entities::Catalog::RevisionPreview), nil sans coupe.
      Revision = Data.define(:kind, :sheet, :cut)
      # course_slug : l'adresse de la leçon (le formulaire d'entraînement y revient) ; material, level : leurs noms ; theme : blue | teal | burgundy ; notions : [Notion].
      Lesson = Data.define(:course_slug, :name, :subtitle, :material, :level, :theme, :notions)
      # sheet : Entities::Catalog::NotionSheet ; figure : Entities::Catalog::Figure | nil (la clé citée est absente de la leçon).
      Notion = Data.define(:slug, :name, :sheet, :figure) do
        def anchor = "notion-#{slug}"

        # L'entraînement de la notion tel que la page le montre : sans correction, propositions dans l'ordre d'affichage. nil sans entraînement.
        def practice = sheet.practice
      end

      EMPTY = Revision.new(kind: :empty, sheet: nil, cut: nil)

      # → Revision. Un élève ou un enseignant ne lit que les notions publiées ; l'équipe relit aussi les brouillons. Une notion sans
      # fiche (ancien contenu) n'est jamais montrée. La lecture d'un brouillon de leçon est l'affaire de ReadPublishedPolicy.
      def call(course_slug:, actor:)
        course = Orm::Course.joins(:material, :level).where(slug: course_slug)
                            .pick(:id, :name, :subtitle, :sheet_theme, :figures, :slug, "materials.name", "levels.name")
        return EMPTY if course.nil?

        id, name, subtitle, theme, figures, slug, material, level = course
        notions = notions_of(id, figures, statuses: actor&.team? ? %w[draft published] : %w[published])
        return EMPTY if notions.empty?

        preview = Entities::Catalog::RevisionPreview.for_notions(notions.map(&:sheet))
        Revision.new(kind: :sheet, sheet: Lesson.new(course_slug: slug, name:, subtitle:, material:, level:, theme:, notions:), cut: (preview if preview.cut?))
      end

      private

      def notions_of(course_id, figures, statuses:)
        by_key = Array(figures).to_h { [ it["key"], Entities::Catalog::Figure.from_raw(it) ] }
        Orm::Essential.where(course_id:, status: statuses).where.not(sheet: {}).order(:position).pluck(:slug, :name, :sheet).map do |slug, name, raw|
          sheet = Entities::Catalog::NotionSheet.from_raw(raw.merge("figure" => raw["figure_key"]))
          sheet = sheet.with(practice: UseCases::Catalog::CheckPractice.shown(sheet.practice)) if sheet.practice
          Notion.new(slug:, name:, sheet:, figure: by_key[sheet.figure_key])
        end
      end
    end
  end
end
