# 🧠 DOMAINE · Ports::Classroom::InviteCodeRepositoryPort
# Rôle : contrat des codes d'invitation des élèves (un code opaque de 8 caractères par élève)
# ADR  : attribution-des-inscriptions-eleves
module Ports
  module Classroom
    module InviteCodeRepositoryPort
      # Crée le code au besoin (3 essais en cas de collision), puis le réutilise. → Shared::Result(String)
      def code_for(student_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #code_for"
      end

      # → Integer (identifiant de l'invitant) | nil ; un élève anonymisé ou un code inconnu ne désigne personne.
      def inviter_for(code:)
        raise NotImplementedError, "#{self.class} doit implémenter #inviter_for"
      end
    end
  end
end
