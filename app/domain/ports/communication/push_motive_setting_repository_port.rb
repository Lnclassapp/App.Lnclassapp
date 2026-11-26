# 🧠 DOMAINE · Ports::Communication::PushMotiveSettingRepositoryPort
# Rôle : contrat des réglages « Automatique » des motifs et de leur historique (gelé par le Lot 0)
# ADR  : XXXX envois de notifications (§4.2)
module Ports
  module Communication
    module PushMotiveSettingRepositoryPort
      # → Set<String> : les motifs dont la case est cochée (absence de ligne = décoché)
      def automatic_motives
        raise NotImplementedError, "#{self.class} doit implémenter #automatic_motives"
      end

      # → [Entities::Communication::PushMotiveSetting]
      def all
        raise NotImplementedError, "#{self.class} doit implémenter #all"
      end

      # Écrit le réglage ET sa ligne d'historique, dans une transaction. `by` : identifiant de l'auteur.
      def update(motive:, automatic:, by:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #update"
      end

      # Additif au contrat de l'ADR §4.2 (purge à 90 jours de l'historique des réglages, ADR §4.1) → nombre supprimé
      def purge_changes_before(before:)
        raise NotImplementedError, "#{self.class} doit implémenter #purge_changes_before"
      end
    end
  end
end
