# 🧠 DOMAINE · Entities::Assessment::GapOutcome
# Rôle : ce qu'une session terminée a fait de la fiche à revoir : ouverte, levée, encore à revoir, ou rien
# ADR  : 0043, 0101
module Entities
  module Assessment
    module GapOutcome
      # gap : répond à id, status, source_session_id, resolved_by_session_id ; nil sans lacune liée.
      # → :opened, :lifted, :still_pending ou nil (ADR-0101 §4.3).
      def self.call(session_id:, session_kind:, knowledge_gap_id:, gap:)
        return if gap.nil?
        return :opened if gap.source_session_id == session_id
        return :lifted if gap.resolved_by_session_id == session_id
        return :still_pending if session_kind == "remediation" && gap.id == knowledge_gap_id && gap.status == "pending"

        nil
      end
    end
  end
end
