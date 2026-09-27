# 🧠 DOMAINE · Entities::Assessment::GapDecision
# Rôle : décide de l'effet d'une clôture sur la lacune d'une fiche
# ADR  : 0033, 0043
module Entities
  module Assessment
    module GapDecision
      # Sous PASS_THRESHOLD, la lacune s'ouvre ou compte un échec de plus ; elle n'est résolue qu'à partir de
      # REMEDIATION_THRESHOLD ; entre les deux, elle reste en attente sans nouvel échec.
      # → :open, :increment, :remediated, :self_corrected ou :none
      def self.call(score_percent:, pending_gap:, session_kind:)
        passed = score_percent >= Grading::PASS_THRESHOLD
        return pending_gap ? :increment : :open unless passed
        return :none unless pending_gap && score_percent >= Grading::REMEDIATION_THRESHOLD

        session_kind.to_s == "remediation" ? :remediated : :self_corrected
      end
    end
  end
end
