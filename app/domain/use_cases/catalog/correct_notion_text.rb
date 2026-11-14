# 🧠 DOMAINE · UseCases::Catalog::CorrectNotionText
# Rôle : l'équipe corrige à l'écran le texte d'une notion (nom et quatre blocs), quel que soit son statut ; la structure reste à l'import ; inscrit au journal
# ADR  : 0035, 0113 (§4.6, amendement du 2026-11-14), 0116 · chantier edition-texte-lecon
module UseCases
  module Catalog
    class CorrectNotionText
      # Le texte saisi : nom, « À retenir », étapes de la méthode, énoncé et étapes de l'exemple, piège. Les étapes gardent leur nombre.
      NotionText = Data.define(:name, :remember, :method_steps, :example_statement, :example_steps, :pitfall)

      def initialize(essentials:, audit_log:, transaction:, policy:, clock:)
        @essentials = essentials
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Essential relue) | :forbidden | :not_found
      #   | :invalid (base: structure_changed | no_sheet | reimport | write_failed ; name: blank | too_long | taken ;
      #              <chemin du bloc>: blank | too_long)
      def call(actor:, slug:, text:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        essential = @essentials.find_by_slug(slug:)
        return Shared::Result.failure(:not_found) if essential.nil?

        written = @transaction.attempt_with_cause { correct(actor, essential, text) }
        return written.value if written.success?

        # Deux renommages simultanés vers le même nom : l'index unique tranche ; le perdant lit « nom déjà pris ».
        written.errors[:cause] == [ :collision ] ? invalid(name: [ :taken ]) : invalid(base: [ :write_failed ])
      end

      private

      # Verrou puis lecture : la fiche comparée est celle qui sera écrite (menace.md, n° 15).
      def correct(actor, essential, text)
        @essentials.lock(id: essential.id)
        raw = @essentials.sheet_of(id: essential.id)
        return invalid(base: [ :no_sheet ]) if raw.blank?
        return invalid(base: [ :structure_changed ]) unless same_structure?(raw, text)

        sheet = merged(raw, text)
        name = text.name.to_s.squish
        errors = name_errors(essential, name).merge(sheet_errors(sheet))
        return invalid(**errors) if errors.any?

        at = @clock.now
        @essentials.correct_text(id: essential.id, name:, sheet:, at:)
        @audit_log.record(action: "content.corrected", actor_id: actor.user_id, at:, subject_type: "Essential",
                          subject_id: essential.id, metadata: { slug: essential.slug })
        Shared::Result.success(@essentials.find_by_slug(slug: essential.slug))
      end

      def same_structure?(raw, text)
        Array(text.method_steps).size == Array(raw["method"]).size &&
          Array(text.example_steps).size == Array(raw.dig("example", "steps")).size
      end

      # Les seules clés du texte sont remplacées : entraînement, figure et toute autre clé de l'import restent.
      def merged(raw, text)
        example = (raw["example"].is_a?(Hash) ? raw["example"] : {})
                  .merge("statement" => text.example_statement.to_s.strip, "steps" => text.example_steps.map { it.to_s.strip })
        raw.merge("remember" => text.remember.to_s.strip, "method" => text.method_steps.map { it.to_s.strip }, "example" => example,
                  "pitfall" => text.pitfall.to_s.strip)
      end

      def name_errors(essential, name)
        return { name: [ :blank ] } if name.empty?
        return { name: [ :too_long ] } if name.length > Entities::Catalog::Essential::NAME_MAX

        owner = @essentials.ids_by_name(course_id: essential.course_id)[Entities::Shared::NaturalKey.normalize(name)]
        owner && owner != essential.id ? { name: [ :taken ] } : {}
      end

      # Chemins d'un champ de la modale ; une erreur ailleurs (nombre d'étapes déjà hors bornes à l'import) se lit en tête : réimporter.
      FIELD_PATH = /\A(remember|pitfall|example\.statement|method\[\d+\]|example\.steps\[\d+\])\z/

      def sheet_errors(sheet)
        Entities::Catalog::NotionSheet.errors_for(sheet).each_with_object({}) do |(path, reason), errors|
          key, code = path.to_s.match?(FIELD_PATH) ? [ path.to_sym, reason.to_sym ] : [ :base, :reimport ]
          (errors[key] ||= []) << code
          errors[key].uniq!
        end
      end

      def invalid(**errors) = Shared::Result.failure(:invalid, errors:)
    end
  end
end
