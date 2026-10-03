# 🧠 DOMAINE · Ports::Identity::LoginAttemptRepositoryPort
# Rôle : contrat du journal des tentatives, base du verrouillage progressif
# ADR  : 0031, 0032, 0050
module Ports
  module Identity
    module LoginAttemptRepositoryPort
      KINDS = %w[pin second_factor].freeze
      Failures = Data.define(:count, :last_failed_at)

      # kind ∈ KINDS ; contact normalisé si possible, brut sinon. → true
      def record(contact:, user_id:, ip:, succeeded:, kind:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record"
      end

      # Échecs de ce type depuis le dernier succès du contact. → Failures (count 0 et last_failed_at nil si aucun)
      def consecutive_failures(contact:, kind:)
        raise NotImplementedError, "#{self.class} doit implémenter #consecutive_failures"
      end

      # Après un PIN réinitialisé. → Integer (lignes remises à zéro)
      def clear_failures(contact:)
        raise NotImplementedError, "#{self.class} doit implémenter #clear_failures"
      end

      # Suppression d'un compte (ADR-0036 §4) : ses tentatives, et celles faites avec son numéro, gardent numéro et IP.
      # → Integer (lignes supprimées)
      def destroy_all_for(user_id:, contact:)
        raise NotImplementedError, "#{self.class} doit implémenter #destroy_all_for"
      end
    end
  end
end
