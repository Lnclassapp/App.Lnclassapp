# 🧠 DOMAINE · Ports::Shared::TransactionPort
# Rôle : contrat de transaction ouvert par un use case qui écrit dans plusieurs tables
# ADR  : 0026, 0027 (erratum : le port vit dans ports/shared), 0039, 0096
module Ports
  module Shared
    module TransactionPort
      # Exécute le bloc dans une transaction et renvoie sa valeur ; une exception annule tout et remonte.
      def call(&block)
        raise NotImplementedError, "#{self.class} doit implémenter #call"
      end

      # Comme call, mais une écriture refusée par la base (contrainte, verrou) annule tout et renvoie
      # failure(:conflict, errors: { base: [:write_failed] }) au lieu de lever. → Result(valeur du bloc)
      def attempt(&block)
        raise NotImplementedError, "#{self.class} doit implémenter #attempt"
      end

      # Comme attempt, mais l'échec dit pourquoi : errors: { base: [:write_failed], cause: [:collision | :other],
      # exception: [classe de l'exception] } ; :collision : une valeur déjà prise (index unique), seul refus qu'un nouvel essai
      # peut lever (ADR-0096 §4.3). → Result(valeur du bloc)
      def attempt_with_cause(&block)
        raise NotImplementedError, "#{self.class} doit implémenter #attempt_with_cause"
      end
    end
  end
end
