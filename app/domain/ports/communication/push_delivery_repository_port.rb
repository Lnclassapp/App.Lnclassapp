# 🧠 DOMAINE · Ports::Communication::PushDeliveryRepositoryPort
# Rôle : contrat des envois : anti-doublon par clé d'objet, dernier envoi, nombre d'envois du jour, purge à 90 jours
# ADR  : 0146 (§4.2) · XXXX envois de notifications (§4.2, `sent_count`)
module Ports
  module Communication
    module PushDeliveryRepositoryPort
      # Un envoi est unique par élève, motif et clé d'objet : l'écriture est un upsert. Un statut provisoire (`disabled`,
      # `not_configured`, `retry`) est remplacé par le nouveau ; un statut définitif (`delivered`, `gone`, `failed`) ne bouge plus.
      # → true si enregistré, false si déjà connu (statut définitif)
      def record(user_id:, motive:, object_key:, status:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record"
      end

      # true pour un statut définitif seulement : un motif noté `disabled` ou `not_configured` n'est pas « brûlé » (mise en service progressive)
      def sent?(user_id:, motive:, object_key:)
        raise NotImplementedError, "#{self.class} doit implémenter #sent?"
      end

      # → Time | nil : le dernier envoi réellement parti (statut `delivered`)
      def last_sent_at(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #last_sent_at"
      end

      # → Integer : les envois `delivered` de ce jour d'Abidjan (= jour UTC), pour le plafond de dix par jour. Additif.
      def sent_count(user_id:, on_date:)
        raise NotImplementedError, "#{self.class} doit implémenter #sent_count"
      end

      # → nombre supprimé
      def purge_before(before:)
        raise NotImplementedError, "#{self.class} doit implémenter #purge_before"
      end
    end
  end
end
