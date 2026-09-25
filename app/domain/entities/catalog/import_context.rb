# 🧠 DOMAINE · Entities::Catalog::ImportContext
# Rôle : ce que l'adaptateur prépare une fois : cible résolue, clés déjà en base, référentiels chargés
# ADR  : 0039
module Entities
  module Catalog
    # existing_keys : Set des clés de doublon en base ; data : référentiels propres à l'adaptateur (lookup, slugs pris…)
    ImportContext = Data.define(:target, :existing_keys, :data) do
      def initialize(target:, existing_keys:, data: {})
        super
      end
    end
  end
end
