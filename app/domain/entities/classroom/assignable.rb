# 🧠 DOMAINE · Entities::Classroom::Assignable
# Rôle : ressource assignable à une classe : un exercice seul (clé = public_id)
# ADR  : 0048, 0072
module Entities
  module Classroom
    Assignable = Data.define(:type, :id, :key, :name) do
      def initialize(type:, id:, key:, name: nil)
        raise ArgumentError, "type assignable inconnu : #{type.inspect}" unless Assignable::TYPES.include?(type)

        super
      end
    end
    # ADR-0072 §4.1 : cours et fiches ne s'assignent plus.
    Assignable::TYPES = %w[Exercise].freeze
  end
end
