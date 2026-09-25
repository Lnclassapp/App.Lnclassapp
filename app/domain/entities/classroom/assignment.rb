# 🧠 DOMAINE · Entities::Classroom::Assignment
# Rôle : assignation d'une ressource à une classe ; une réassignation crée une nouvelle ligne
# ADR  : 0048
module Entities
  module Classroom
    Assignment = Data.define(:id, :public_id, :classroom_id, :assignable, :status, :assigned_by_id, :assigned_at,
                             :archived_at) do
      def active? = status == "active"
    end
    Assignment::STATUSES = %w[active archived].freeze
  end
end
