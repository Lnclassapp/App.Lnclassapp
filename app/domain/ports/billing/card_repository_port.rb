# 🧠 DOMAINE · Ports::Billing::CardRepositoryPort
# Rôle : contrat des lots et des cartes d'activation ; l'activation et l'annulation vérifient l'état de la carte
# ADR  : 0126 (contexte billing, §4.3)
module Ports
  module Billing
    module CardRepositoryPort
      # Crée le lot et ses cartes remises (numéro et code uniques). → Entities::Billing::CardBatch (avec ses cartes)
      def create_batch(relay_point_id:, quantity:, unit_price_xof:, valid_until:, created_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_batch"
      end

      # Par numéro croissant. → [Entities::Billing::ActivationCard]
      def cards_of_batch(batch_public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #cards_of_batch"
      end

      # code : normalisé. À appeler dans une transaction (SELECT … FOR UPDATE). → Entities::Billing::ActivationCard | nil
      def lock_by_code(code:)
        raise NotImplementedError, "#{self.class} doit implémenter #lock_by_code"
      end

      # → Result(ActivationCard) | failure(:conflict, base: [:card_used | :already_subscribed]) | failure(:invalid, base: [:card_cancelled])
      def activate(card_id:, student_id:, school_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #activate"
      end

      # Fin du dernier abonnement activé. → Date | nil
      def subscribed_until(student_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #subscribed_until"
      end

      # → Entities::Billing::ActivationCard | nil
      def find_by_serial(serial:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_serial"
      end

      # → Result(ActivationCard) | failure(:conflict, base: [:card_activated | :card_cancelled])
      def cancel(card_id:, by_id:, reason:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #cancel"
      end
    end
  end
end
