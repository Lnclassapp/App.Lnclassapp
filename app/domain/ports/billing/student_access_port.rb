# 🧠 DOMAINE · Ports::Billing::StudentAccessPort
# Rôle : contrat de lecture de l'accès d'un élève, reçu par les use cases qui démarrent un exercice ou vérifient une fiche
# ADR  : cartes-activation (contexte billing, §4.6)
module Ports
  module Billing
    module StudentAccessPort
      # Jamais bloqué hors élève. → Entities::Billing::Access
      def call(student_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #call"
      end
    end
  end
end
