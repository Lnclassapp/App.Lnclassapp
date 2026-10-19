# 🧠 DOMAINE · Entities::Assessment::GapDecision
# Rôle : décide de l'effet d'une clôture sur la lacune d'une fiche, sur la note affichée sur 20
# ADR  : 0033, 0043, 0101 (§4.5)
module Entities
  module Assessment
    module GapDecision
      # Décision du porteur (2026-10-19) : ce que l'élève lit fait foi. On compare la note affichée (Grading.grade_on_20,
      # le seul endroit de l'arrondi) aux notes des seuils, jamais le pourcentage brut : 74 % s'affiche 15/20 et lève,
      # 49 % s'affiche 10/20 et n'ouvre pas. Sous la note de PASS_THRESHOLD, la lacune s'ouvre ou compte un échec de
      # plus ; elle n'est résolue qu'à partir de celle de REMEDIATION_THRESHOLD ; entre les deux, elle reste en attente.
      # → :open, :increment, :remediated, :self_corrected ou :none
      def self.call(score_percent:, pending_gap:, session_kind:)
        grade = Grading.grade_on_20(score_percent)
        passed = grade >= Grading.grade_on_20(Grading::PASS_THRESHOLD)
        return pending_gap ? :increment : :open unless passed
        return :none unless pending_gap && grade >= Grading.grade_on_20(Grading::REMEDIATION_THRESHOLD)

        session_kind.to_s == "remediation" ? :remediated : :self_corrected
      end
    end
  end
end
