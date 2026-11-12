# 🧠 DOMAINE · Ports::Assessment::OfflinePackSignerPort
# Rôle : contrat du jeton signé d'un paquet de corrigé (élève, exercice, version, heure d'émission), sans état serveur
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4, menace C3, P4, R4)
module Ports
  module Assessment
    module OfflinePackSignerPort
      # → String (le jeton, expire au bout de 30 jours). issued_at : Time ; digest : l'empreinte de version de l'exercice.
      def sign(student_id:, exercise_id:, digest:, issued_at:)
        raise NotImplementedError, "#{self.class} doit implémenter #sign"
      end

      # → { student_id:, exercise_id:, digest:, issued_at: (Time) } ou nil (jeton falsifié, expiré, d'un autre but, illisible).
      def verify(token)
        raise NotImplementedError, "#{self.class} doit implémenter #verify"
      end
    end
  end
end
