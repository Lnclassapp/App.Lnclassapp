# 🧠 DOMAINE · Entities::Catalog::BaseReferential
# Rôle : le référentiel de base (niveaux, séries par niveau, matières) des semis de développement et du complément de Develop
# ADR  : 0034, 0123
module Entities
  module Catalog
    module BaseReferential
      Level = Data.define(:name, :cycle, :position)
      Material = Data.define(:name, :shortname, :category)

      # La position d'un niveau est son rang dans le programme (6ème = 1).
      LEVELS = [ [ "6ème", "first" ], [ "5ème", "first" ], [ "4ème", "first" ], [ "3ème", "first" ],
                 [ "2nde", "second" ], [ "1ère", "second" ], [ "Tle", "second" ] ]
               .each_with_index.map { |(name, cycle), index| Level.new(name:, cycle:, position: index + 1) }.freeze
      SERIES_BY_LEVEL = { "2nde" => %w[A C], "1ère" => %w[A1 A2 C D], "Tle" => %w[A1 A2 C D] }.freeze
      MATERIALS = [ [ "Mathématiques", "Maths", "science" ], [ "Physique-Chimie", "PC", "science" ], [ "SVT", "SVT", "science" ],
                    [ "Français", "Français", "literature" ], [ "Histoire-Géographie", "HG", "literature" ],
                    [ "Philosophie", "Philo", "literature" ] ]
                  .map { |name, shortname, category| Material.new(name:, shortname:, category:) }.freeze
    end
  end
end
