# 🧠 DOMAINE · Entities::Catalog::ImportItem
# Rôle : verdict d'un élément racine : sa clé de doublon, son plan d'écriture, ou ses erreurs
# ADR  : 0039
module Entities
  module Catalog
    # key : clé de doublon normalisée ; plan : ce que l'adaptateur écrira, opaque pour le moteur ; errors : [ImportError]
    ImportItem = Data.define(:path, :key, :plan, :errors) do
      def initialize(path:, key: nil, plan: nil, errors: [])
        super
      end

      def valid? = errors.empty?
    end
  end
end
