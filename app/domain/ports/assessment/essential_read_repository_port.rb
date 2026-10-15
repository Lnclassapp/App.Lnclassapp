# 🧠 DOMAINE · Ports::Assessment::EssentialReadRepositoryPort
# Rôle : contrat de l'enregistrement d'une fiche ouverte par un élève, une ligne par élève et par fiche
# ADR  : 0090 (§4.1)
module Ports
  module Assessment
    module EssentialReadRepositoryPort
      # Idempotent sur (student_id, essential_id) : la première ouverture pose first_read_at, chaque ouverture avance
      # last_read_at. → true
      def record(student_id:, essential_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record"
      end
    end
  end
end
