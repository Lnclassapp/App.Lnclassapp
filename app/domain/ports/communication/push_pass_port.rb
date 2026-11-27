# 🧠 DOMAINE · Ports::Communication::PushPassPort
# Rôle : demander un passage d'envoi des notifications tout de suite, après un événement qui touche des élèves
# ADR  : 0147 (amendement du 2026-11-27 II)
module Ports
  module Communication
    module PushPassPort
      # Ne lève jamais : un échec est signalé par l'adaptateur, l'événement est déjà enregistré et le passage de 15 min le rattrape.
      # → nil
      def request
        raise NotImplementedError, "#{self.class} doit implémenter #request"
      end
    end
  end
end
