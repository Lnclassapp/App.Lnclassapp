# 🔌 INFRA · Repositories::Catalog::ReferentialCompleter
# Rôle : crée sur Develop ce qui manque du référentiel (niveaux, séries, couples, matières, barème des classes, DRENA), sans toucher à l'existant
# ADR  : 0123, 0034, 0058, 0090
module Repositories
  module Catalog
    class ReferentialCompleter
      include Ports::Catalog::ReferentialCompleterPort

      Base = Entities::Catalog::BaseReferential
      DRENAS = Rails.root.join("db/seeds/data/drenas.yml")

      # Une interruption (base coupée…) rend ce qui a déjà été créé, avec l'interruption dans les conflits : rien ne se perd au journal.
      def complete
        @created = { levels: [], series: [], pairs: [], materials: [], plan_entries: [], drenas: [], conflicts: [] }
        levels = Base::LEVELS.to_h { [ it.name, level(it) ] }
        series = Base::SERIES_BY_LEVEL.values.flatten.uniq.to_h { [ it, series(it) ] }
        Base::SERIES_BY_LEVEL.each do |level_name, names|
          names.each { pair(levels[level_name], series[it], "#{level_name} #{it}") }
        end
        Base::PROGRAMME_MATERIALS.each { material(it) }
        plan_entries
        YAML.load_file(DRENAS).each { drena(it) }
        @created
      rescue StandardError => error
        @created.fetch(:conflicts) << "interrompu (#{error.class})"
        @created
      end

      private

      def level(base)
        position = free_position(base.position)
        label = position == base.position ? base.name : "#{base.name} (position #{position})"
        Orm::Level.find_by(slug: base.name.parameterize) || create(:levels, "niveau", label) do
          Orm::Level.create!(name: base.name, cycle: base.cycle, position:)
        end
      end

      def series(name)
        Orm::Series.find_by(slug: name.parameterize) || create(:series, "série", name) { Orm::Series.create!(name:) }
      end

      def pair(level, series, label)
        return if level.nil? || series.nil? || Orm::LevelSeries.exists?(level:, series:)

        create(:pairs, "couple", label) { Orm::LevelSeries.create!(level:, series:) }
      end

      def material(base)
        return if Orm::Material.exists?(slug: base.name.parameterize)

        create(:materials, "matière", base.name) do
          Orm::Material.create!(name: base.name, shortname: base.shortname, category: base.category,
                                position: Repositories::Catalog::ProgramOrder.rank(base.name.parameterize))
        end
      end

      # Le barème des classes de l'ADR-0058 sur le référentiel en base : seules les entrées absentes (ON CONFLICT DO NOTHING), un nombre
      # posé par l'équipe n'est jamais réécrit. → les ids des entrées créées
      def plan_entries
        require Rails.root.join("db/migrate/20260928140100_fill_classroom_plan_entries").to_s
        before = Orm::ClassroomPlanEntry.maximum(:id).to_i
        FillClassroomPlanEntries.fill
        @created[:plan_entries] = Orm::ClassroomPlanEntry.where(id: (before + 1)..).pluck(:id)
      end

      def drena(name)
        return if Orm::Drena.exists?(slug: Entities::School::Drena.slug_for(name))

        create(:drenas, "DRENA", name) { Orm::Drena.create!(name:) }
      end

      # La position du référentiel, ou la première libre après la plus haute si un autre niveau la tient (index unique).
      def free_position(position)
        Orm::Level.exists?(position:) ? Orm::Level.maximum(:position).to_i + 1 : position
      end

      # Une création à part (point de sauvegarde) : une valeur unique (nom, nom court, position) déjà prise par un autre enregistrement est
      # notée, jamais levée. → l'enregistrement | nil
      def create(kind, label, name)
        record = ActiveRecord::Base.transaction(requires_new: true) { yield }
        @created.fetch(kind) << name
        record
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        @created.fetch(:conflicts) << "#{label} #{name}"
        nil
      end
    end
  end
end
