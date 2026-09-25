# 🧠 DOMAINE · Entities::Classroom::Assignable
# Rôle : ressource assignable à une classe : cours, fiche ou exercice (clé = slug ou public_id)
# ADR  : 0048
module Entities
  module Classroom
    Assignable = Data.define(:type, :id, :key, :name) do
      def initialize(type:, id:, key:, name: nil)
        raise ArgumentError, "type assignable inconnu : #{type.inspect}" unless Assignable::TYPES.include?(type)

        super
      end
    end
    Assignable::TYPES = %w[Course Essential Exercise].freeze
  end
end
