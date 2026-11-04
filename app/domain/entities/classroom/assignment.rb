# 🧠 DOMAINE · Entities::Classroom::Assignment
# Rôle : assignation d'une ressource à une classe, avec son échéance figée ; une réassignation crée une nouvelle ligne
# ADR  : 0048, 0072, sujets-de-devoir (ajout du 2026-10-30)
module Entities
  module Classroom
    Assignment = Data.define(:id, :public_id, :classroom_id, :assignable, :status, :assigned_by_id, :assigned_at,
                             :archived_at, :due_on, :batch_public_id) do
      # due_on : le prochain jour de séance de l'auteur, calculé à l'assignation (ADR-0072 §4.3) ; nil sans jours.
      # batch_public_id : l'envoi (plusieurs exercices en un devoir) qui a créé l'assignation ; nil pour un exercice assigné seul.
      def initialize(due_on: nil, batch_public_id: nil, **attributes) = super

      def active? = status == "active"
    end
    Assignment::STATUSES = %w[active archived].freeze
  end
end
