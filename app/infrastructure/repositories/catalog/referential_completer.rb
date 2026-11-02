# 🔌 INFRA · Repositories::Catalog::ReferentialCompleter
# Rôle : crée sur Develop les niveaux, séries, couples et matières du référentiel de base qui manquent, sans toucher à l'existant
# ADR  : 0123, 0034, 0090
module Repositories
  module Catalog
    class ReferentialCompleter
      include Ports::Catalog::ReferentialCompleterPort

      Base = Entities::Catalog::BaseReferential

      # Une interruption (base coupée…) rend ce qui a déjà été créé, avec l'interruption dans les conflits : rien ne se perd au journal.
      def complete
        @created = { levels: [], series: [], pairs: [], materials: [], conflicts: [] }
        levels = Base::LEVELS.to_h { [ it.name, level(it) ] }
        series = Base::SERIES_BY_LEVEL.values.flatten.uniq.to_h { [ it, series(it) ] }
        Base::SERIES_BY_LEVEL.each do |level_name, names|
          names.each { pair(levels[level_name], series[it], "#{level_name} #{it}") }
        end
        Base::MATERIALS.each { material(it) }
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
