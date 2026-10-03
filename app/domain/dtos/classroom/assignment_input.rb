# 🧠 DOMAINE · Dtos::Classroom::AssignmentInput
# Rôle : ressource à assigner à une classe : son type (cours, fiche essentielle, exercice) et sa clé (slug ou public_id)
# ADR  : 0026, 0029, 0048
module Dtos
  module Classroom
    class AssignmentInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :classroom_public_id, :string
      attribute :assignable_type, :string
      # Slug d'un cours ou d'une fiche essentielle, public_id d'un exercice (ADR-0029).
      attribute :assignable_key, :string

      validates :classroom_public_id, :assignable_key, presence: true
      validates :assignable_type, inclusion: { in: Entities::Classroom::Assignable::TYPES }

      def assignable_key = super.to_s.strip
    end
  end
end
