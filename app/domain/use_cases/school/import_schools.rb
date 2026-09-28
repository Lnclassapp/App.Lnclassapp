# 🧠 DOMAINE · UseCases::School::ImportSchools
# Rôle : adaptateur d'import des établissements (clés de l'ancien acceptées), chacun écrit avec ses classes générées
# ADR  : 0028, 0030, 0039, 0041, 0058 · UDR : 0037
module UseCases
  module School
    class ImportSchools
      include UseCases::Catalog::Importer

      KIND = "schools"
      # Le moteur autorise l'auteur par le registre des types (ImportKind) ; c'est la même policy.
      POLICY = Policies::School::ManageSchoolPolicy
      PUBLIC_ID_LENGTH = 14
      # Clé canonique de l'élément → clés acceptées, la première présente l'emporte (ADR-0039).
      ALIASES = { "name" => %w[name nom], "sigle" => %w[sigle schoolsigle], "status" => %w[status schoolstatus statut],
                  "type" => %w[type schooltype], "cycle" => %w[cycle] }.freeze
      # Valeur normalisée (NaturalKey) → type stocké.
      SCHOOL_TYPES = { "public" => "public", "privee" => "private", "prive" => "private", "private" => "private",
                       "mixte" => "mixed", "mixed" => "mixed" }.freeze
      # Attribut de l'entité → clé canonique où l'erreur est notée.
      ERROR_KEYS = { name: "name", sigle: "sigle", status: "status", school_type: "type", cycle: "cycle" }.freeze
      ERROR_CODES = { blank: "blank", too_long: "too_long", inclusion: "invalid_value" }.freeze

      # classroom_plan : le barème, lu une fois à la préparation (ADR-0058) ; random : tirage des codes, injectable.
      def initialize(drenas:, schools:, classrooms:, taxonomy:, classroom_plan:, random: SecureRandom)
        @drenas = drenas
        @schools = schools
        @classrooms = classrooms
        @taxonomy = taxonomy
        @classroom_plan = classroom_plan
        @random = random
      end

      # La DRENA de l'enveloppe est facultative : chaque école peut porter la sienne.
      def resolve_target(document:)
        return Shared::Result.success(nil) unless document.key?("drena")

        drena = @drenas.find_by_slug(slug: document["drena"].to_s.parameterize)
        return Shared::Result.failure(:not_found) if drena.nil?

        Shared::Result.success(drena)
      end

      # Les codes déjà pris (classes et établissements) sont gardés pour write, qui les complète lot après lot.
      def prepare(target:)
        ids_by_slug = @drenas.ids_by_slug
        @taken_codes = @classrooms.taken_join_codes
        @taken_school_codes = @schools.taken_school_codes
        Entities::Catalog::ImportContext.new(target:, existing_keys: @schools.existing_keys(drena_ids: ids_by_slug.values),
                                             data: { ids_by_slug:, lookup: @taxonomy.lookup, plan: @classroom_plan.plan,
                                                                     taken_codes: @taken_codes })
      end

      def validate_root(root:, path:, context:)
        values = ALIASES.transform_values { |keys| root[keys.find { root.key?(it) }] }
        drena_id, drena_errors = drena_for(root, path, context)
        school = build_school(values, drena_id)
        errors = drena_errors + school_errors(school, values, path)
        return Entities::Catalog::ImportItem.new(path:, errors:) if errors.any?

        Entities::Catalog::ImportItem.new(path:, key: [ drena_id, Entities::Shared::NaturalKey.normalize(school.name) ],
                                          plan: plan_for(school, context.data))
      end

      # Les écoles avec leur code, puis toutes les classes du lot, dans la transaction du moteur : un refus annule les deux.
      def write(items:, author_id:, at:)
        inserted = @schools.insert_many(rows: with_school_codes(items.map { it.plan.fetch(:school) }), at:)
        school_ids = inserted.to_h { [ it.public_id, it.id ] }
        school_year = Entities::Classroom::SchoolYear.current(at.to_date)
        rows = items.flat_map do |item|
          school_id = school_ids.fetch(item.plan.fetch(:school).fetch(:public_id))
          item.plan.fetch(:classrooms).map { it.merge(school_id:, school_year:) }
        end
        created = @classrooms.insert_generated(rows: with_codes(rows), at:)
        { imported: items.size, details: details(items, created) }
      end

      private

      # → [drena_id, errors] : la DRENA de l'élément, sinon celle de l'enveloppe.
      def drena_for(root, path, context)
        if root.key?("drena")
          drena_id = context.data.fetch(:ids_by_slug)[root["drena"].to_s.parameterize]
          return [ drena_id, [] ] if drena_id

          return [ nil, [ error("#{path}.drena", "unknown_drena", value: root["drena"]) ] ]
        end
        return [ context.target.id, [] ] if context.target

        [ nil, [ error("#{path}.drena", "unknown_drena") ] ]
      end

      def build_school(values, drena_id)
        name = values["name"]
        Entities::School::School.new(
          public_id: SecureRandom.base58(PUBLIC_ID_LENGTH), drena_id:, name:, sigle: values["sigle"],
          school_type: SCHOOL_TYPES[Entities::Shared::NaturalKey.normalize(values["type"])],
          cycle: cycle_of(values["cycle"], name), status: normalized(values["status"]) || "active"
        )
      end

      def cycle_of(given, name)
        return Entities::School::School.cycle_for(name:) if given.nil?

        normalized(given)
      end

      def normalized(value)
        return if value.nil?

        value.to_s.squish.downcase
      end

      # La DRENA manquante est déjà signalée par drena_for.
      def school_errors(school, values, path)
        school.validate
        school.errors.filter_map do |failure|
          key = ERROR_KEYS[failure.attribute]
          next if key.nil?

          code = ERROR_CODES.fetch(failure.type)
          next error("#{path}.#{key}", "too_long", max: failure.options[:count]) if code == "too_long"
          next error("#{path}.#{key}", "blank") if code == "blank" || values[key].to_s.strip.empty?

          error("#{path}.#{key}", code, value: values[key])
        end
      end

      def plan_for(school, data)
        generation = Entities::Classroom::DefaultClassroomPlan.rows_for(school:, lookup: data.fetch(:lookup), plan: data.fetch(:plan))
        { school: { public_id: school.public_id, drena_id: school.drena_id, name: school.name, sigle: school.sigle,
                    school_type: school.school_type, cycle: school.cycle, status: school.status },
          classrooms: generation.rows, skipped: generation.skipped }
      end

      # Codes d'établissement uniques en base et dans tout l'import (ADR-0057).
      def with_school_codes(rows)
        codes = Entities::School::SchoolCode.generate_unique(count: rows.size, taken: @taken_school_codes)
        rows.zip(codes).map { |row, school_code| row.merge(school_code:) }
      end

      # Codes uniques en base et dans tout le lot (ADR-0041).
      def with_codes(rows)
        codes = Entities::Classroom::JoinCode.generate_unique(count: rows.size, taken: @taken_codes, random: @random)
        rows.zip(codes).map { |row, join_code| row.merge(join_code:, public_id: SecureRandom.base58(PUBLIC_ID_LENGTH)) }
      end

      # Les niveaux et séries sautés ne paraissent au rapport que s'il y en a.
      def details(items, created)
        skipped = items.map { it.plan.fetch(:skipped) }
        counts = { "skipped_levels" => skipped.sum { it[:levels].size }, "skipped_series" => skipped.sum { it[:series].size } }
        { "classrooms_created" => created, **counts.select { |_, count| count.positive? } }
      end

      def error(path, code, **params) = Entities::Catalog::ImportError.new(path:, code:, params:)
    end
  end
end
