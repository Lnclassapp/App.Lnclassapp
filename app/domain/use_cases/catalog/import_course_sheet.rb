# 🧠 DOMAINE · UseCases::Catalog::ImportCourseSheet
# Rôle : adaptateur d'import d'une fiche de cours (document de blocs) sur sa leçon ; entière ou refusée, jamais écrasée
# ADR  : 0110-fiche-de-cours-en-donnees-importees (contenu-en-blocs, #318), 0028, 0039
module UseCases
  module Catalog
    class ImportCourseSheet
      include UseCases::Catalog::Importer

      KIND = "course_sheet"
      POLICY = Policies::Catalog::ManageContentPolicy
      # Une fiche n'a pas de liste d'éléments : le moteur en veut une, résolue ici (voir #resolve_target).
      ROOT_KEY = "sheet"
      STORED_KEYS = %w[pages glossary].freeze

      # La base a refusé une fiche que la validation avait admise (une autre fiche écrite entre-temps) : rien n'est caché.
      class WriteFailed < StandardError; end

      def initialize(courses:, sheets:)
        @courses = courses
        @sheets = sheets
      end

      # La leçon cible, par son slug exact. Le fichier entier est une seule fiche : le moteur compte des éléments racines, on lui
      # en donne un (le contenu de l'enveloppe), après que son schéma a été contrôlé. Le fichier est ainsi importé ou refusé en bloc.
      def resolve_target(document:)
        course = @courses.find_by_slug(slug: document["course"].to_s.strip)
        return Shared::Result.failure(:not_found) if course.nil?

        document[ROOT_KEY] = [ document.slice("theme", *STORED_KEYS) ]
        Shared::Result.success(course)
      end

      def prepare(target:)
        existing = @sheets.exists_for_course?(course_id: target.id) ? [ [ target.id ] ] : []
        Entities::Catalog::ImportContext.new(target:, existing_keys: existing.to_set)
      end

      # La clé est la leçon : une fiche existante rend le fichier « ignoré », sans rien comparer ni modifier.
      def validate_root(root:, path:, context:)
        sheet = Entities::Catalog::CourseSheet.new(course_id: context.target.id, theme: root["theme"], document: root.slice(*STORED_KEYS),
                                                   format_version: Entities::Catalog::CourseSheet::FORMAT_VERSION)
        errors = sheet.document_errors.map { located(it) }
        return Entities::Catalog::ImportItem.new(path:, errors:) if errors.any?

        Entities::Catalog::ImportItem.new(path:, plan: sheet, key: [ context.target.id ])
      end

      # Une fiche refusée par la base lève : le moteur passe le rapport en « failed ». Relancé, le fichier compte en doublon.
      def write(items:, author_id:, at:)
        items.each do |item|
          result = @sheets.create(sheet: item.plan)
          raise WriteFailed, "fiche de la leçon #{item.plan.course_id} non écrite : #{result.code}" if result.failure?
        end
        { imported: items.size, details: {} }
      end

      private

      # Page, section et position du bloc en cause, avec la raison : le rapport les porte en paramètres.
      def located(error)
        params = { page: error.page, section: error.section, position: error.position, reason: error.reason.to_s, detail: error.detail&.to_s }
        Entities::Catalog::ImportError.new(path: path_of(error), code: "invalid_value", params: params.compact)
      end

      def path_of(error)
        # Le chemin suit le JSON du fichier (indices depuis 0, comme les autres types) ; les paramètres comptent depuis 1.
        parts = [ ("pages[#{error.page - 1}]" if error.page), ("sections[#{error.section - 1}]" if error.section),
                  ("blocks[#{error.position - 1}]" if error.position) ].compact
        return parts.join(".") if parts.any?

        error.detail.to_s.start_with?("glossary") ? "glossary" : "$"
      end
    end
  end
end
