# 🧠 DOMAINE · Entities::Assessment::RestartPause
# Rôle : la pause de « Recommencer » après 3 copies vérifiées d'affilée sur un exercice, et l'heure de reprise
# ADR  : 0115 (§4 ; PRD §3 « La pause » : moins de 30 minutes de la fin d'une copie à la fin de la suivante)
module Entities
  module Assessment
    module RestartPause
      STREAK = 3
      # Secondes : l'écart « d'affilée » entre deux fins, et la durée de la pause après la fin de la 3e.
      WINDOW = 30 * 60

      # completions : les fins (Time) des copies terminées de l'élève sur l'exercice, dans n'importe quel ordre ; seules les
      # 3 dernières comptent. → Time (l'heure de reprise) si l'élève est en pause à `now`, nil sinon.
      def self.resume_at(completions:, now:)
        last = completions.sort.last(STREAK)
        return nil unless last.size == STREAK && last.each_cons(2).all? { |earlier, later| later - earlier < WINDOW }

        resume = last.last + WINDOW
        resume if now < resume
      end
    end
  end
end
