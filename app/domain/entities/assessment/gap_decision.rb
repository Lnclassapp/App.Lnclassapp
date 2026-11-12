# 🧠 DOMAINE · Entities::Assessment::GapDecision
# Rôle : décide de l'effet d'une clôture sur la lacune d'une fiche, sur la note affichée sur 20
# ADR  : 0033, 0043 (amendé le 2026-11-09), 0101 (§4.5), 0106
module Entities
  module Assessment
    module GapDecision
      # Une seule échelle, la médaille (décisions du porteur, 2026-10-19 puis 2026-11-09) : « quand la médaille est Argent, l'élève est
      # dans la remédiation ; seules l'Or et le Diamant n'y sont pas ». Lue sur la note affichée (Grading.reaches?, le seul endroit de
      # l'arrondi : 77 % s'affiche 15/20, Argent). Sous l'Or (Bronze ou Argent), la lacune s'ouvre ou compte un échec de plus ; à l'Or
      # et au Diamant, une lacune en attente est levée, sinon rien. Une copie sans réponse (treated faux) n'a aucune médaille : elle
      # n'ouvre rien et ne compte rien.
      # → :open, :increment, :remediated, :self_corrected ou :none
      def self.call(score_percent:, pending_gap:, session_kind:, treated:)
        return :none unless treated
        return pending_gap ? :increment : :open unless Grading.reaches?(score_percent, Grading::GOLD_THRESHOLD)
        return :none unless pending_gap

        session_kind.to_s == "remediation" ? :remediated : :self_corrected
      end
    end
  end
end
