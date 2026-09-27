# 🧠 DOMAINE · Entities::Assessment::KnowledgeGap
# Rôle : lacune d'un élève sur une fiche, ouverte par une clôture sous le seuil de réussite
# ADR  : 0043
module Entities
  module Assessment
    KnowledgeGap = Data.define(:id, :student_id, :essential_id, :status, :failed_sessions_count) do
      def pending? = status == "pending"
    end
    KnowledgeGap::STATUSES = %w[pending remediated self_corrected].freeze
  end
end
