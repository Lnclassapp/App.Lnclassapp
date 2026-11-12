# 🧠 DOMAINE · Ports::Assessment::OfflinePackDeliveryRepositoryPort
# Rôle : contrat de la trace « le corrigé hors ligne de cet exercice a été remis à cet élève », une ligne par élève et exercice
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4, amendement « Devoir à rendre »)
module Ports
  module Assessment
    module OfflinePackDeliveryRepositoryPort
      # Enregistre une remise : crée la ligne, ou avance last_delivered_at. first_delivered_at n'est jamais reculé ni avancé.
      def record(student_id:, exercise_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record"
      end

      # → Time | nil : la première remise du corrigé de cet exercice à cet élève.
      def first_delivered_at(student_id:, exercise_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #first_delivered_at"
      end
    end
  end
end
