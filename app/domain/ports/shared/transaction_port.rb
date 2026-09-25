# 🧠 DOMAINE · Ports::Shared::TransactionPort
# Rôle : contrat de transaction ouvert par un use case qui écrit dans plusieurs tables
# ADR  : 0026, 0027 (erratum : le port vit dans ports/shared)
module Ports
  module Shared
    module TransactionPort
      # Exécute le bloc dans une transaction et renvoie sa valeur ; une exception annule tout.
      def call(&block)
        raise NotImplementedError, "#{self.class} doit implémenter #call"
      end
    end
  end
end
