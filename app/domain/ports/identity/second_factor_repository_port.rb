# 🧠 DOMAINE · Ports::Identity::SecondFactorRepositoryPort
# Rôle : contrat du second facteur TOTP (rotp côté repository) et des codes de secours
# ADR  : 0031
module Ports
  module Identity
    module SecondFactorRepositoryPort
      State = Data.define(:confirmed, :backup_codes_left)
      Enrollment = Data.define(:secret, :provisioning_uri)

      # → State | nil (aucun secret)
      def state_for(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #state_for"
      end

      # Remplace un secret non confirmé. → Enrollment
      def begin_enrollment(user_id:, label:)
        raise NotImplementedError, "#{self.class} doit implémenter #begin_enrollment"
      end

      # ±1 pas ; refuse un pas ≤ last_used_step, puis l'enregistre. → Integer (pas accepté) | nil
      def verify_code(user_id:, code:, now:)
        raise NotImplementedError, "#{self.class} doit implémenter #verify_code"
      end

      # Pose confirmed_at et remplace les codes de secours existants. → true
      def confirm(user_id:, backup_code_digests:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #confirm"
      end

      # → Boolean (vrai si un code inutilisé correspondait)
      def consume_backup_code(user_id:, code_digest:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #consume_backup_code"
      end

      # Supprime le secret et les codes. → true
      def reset(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #reset"
      end
    end
  end
end
