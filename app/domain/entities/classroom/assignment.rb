# 🧠 DOMAINE · Entities::Classroom::Assignment
# Rôle : assignation d'une ressource à une classe, avec son échéance figée ; une réassignation crée une nouvelle ligne
# ADR  : 0048, 0072
module Entities
  module Classroom
    Assignment = Data.define(:id, :public_id, :classroom_id, :assignable, :status, :assigned_by_id, :assigned_at,
                             :archived_at, :due_on) do
      # due_on : le prochain jour de séance de l'auteur, calculé à l'assignation (ADR-0072 §4.3) ; nil sans jours.
      def initialize(due_on: nil, **attributes) = super

      def active? = status == "active"
    end
    Assignment::STATUSES = %w[active archived].freeze
  end
end
