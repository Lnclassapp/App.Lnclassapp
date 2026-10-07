# 🧠 DOMAINE · Ports::Identity::UserRepositoryPort
# Rôle : contrat de lecture des comptes et de leur PIN (bcrypt côté repository) ; anonymisation d'un compte
# ADR  : 0026, 0028, 0036, 0050, 0055, 0082
module Ports
  module Identity
    module UserRepositoryPort
      # → Entities::Identity::User | nil
      def find(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find"
      end

      # → Entities::Identity::User | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # → Entities::Identity::User | nil ; contact déjà normalisé
      def find_by_contact(contact:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_contact"
      end

      # → Entities::Identity::User | nil ; temps constant, même pour un numéro inconnu
      def authenticate(contact:, pin:)
        raise NotImplementedError, "#{self.class} doit implémenter #authenticate"
      end

      # → true
      def update_pin(user_id:, pin:)
        raise NotImplementedError, "#{self.class} doit implémenter #update_pin"
      end

      # → true ; noms déjà validés par le domaine
      def update_name(user_id:, first_name:, last_name:)
        raise NotImplementedError, "#{self.class} doit implémenter #update_name"
      end

      # → Shared::Result : success | :conflict (errors { contact: [:taken] }) si le numéro appartient à un autre compte
      def update_contact(user_id:, contact:)
        raise NotImplementedError, "#{self.class} doit implémenter #update_contact"
      end

      # ADR-0036 §4 : nom remplacé, contact nul, PIN remplacé par un secret aléatoire tiré ici et jamais rendu, anonymized_at
      # posé. → true
      def anonymize(user_id:, first_name:, last_name:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #anonymize"
      end

      # ADR-0082 §4.3 : heure de la dernière ouverture de Lnclass depuis l'icône de l'app installée. → true
      def mark_app_opened(user_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #mark_app_opened"
      end

      # → Entities::Identity::Actor ; school_id = école principale de l'enseignant, sinon nil
      def actor_for(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #actor_for"
      end
    end
  end
end
