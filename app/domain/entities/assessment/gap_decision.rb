# 🧠 DOMAINE · Entities::Assessment::GapDecision
# Rôle : décide de l'effet d'une clôture sur la lacune d'une fiche
# ADR  : 0033, 0043
module Entities
  module Assessment
    module GapDecision
      # → :open, :increment, :remediated, :self_corrected ou :none
      def self.call(score_percent:, pending_gap:, session_kind:)
        passed = score_percent >= Grading::PASS_THRESHOLD
        return pending_gap ? :increment : :open unless passed
        return :none unless pending_gap

        session_kind.to_s == "remediation" ? :remediated : :self_corrected
      end
    end
  end
end
