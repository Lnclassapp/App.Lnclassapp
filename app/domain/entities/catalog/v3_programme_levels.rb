# 🧠 DOMAINE · Entities::Catalog::V3ProgrammeLevels
# Rôle : liste explicite des dossiers de niveaux du programme contenus-v3-tous-niveaux, que Develop charge et remplace entiers
# ADR  : 0123
module Entities
  module Catalog
    module V3ProgrammeLevels
      # Les dossiers de docs/contenus/lecons-traitees/ (un par niveau et groupe de séries). Tle et 1ère sont fusionnés ; 2nde, 4ème,
      # 5ème et 6ème le seront vague après vague : seuls leurs fichiers au format 3 sont lus, les autres attendent. 3ème n'en fait pas partie
      # (programme antérieur) : seules ses leçons à sujets de devoir se chargent (ADR-0122).
      DIRECTORIES = %w[tle tle-a1 tle-a2 tle-c tle-d
                       1ere 1ere-a1 1ere-a2 1ere-c 1ere-d
                       2nde 2nde-a 2nde-c
                       4eme 5eme 6eme].to_set.freeze

      def self.include?(directory) = DIRECTORIES.include?(directory)
    end
  end
end
