# 🧠 DOMAINE · Ports::Identity::UserRepositoryPort
# Rôle : contrat de lecture des comptes et de leur PIN (bcrypt côté repository)
# ADR  : 0026, 0028, 0050
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

      # → Entities::Identity::Actor ; school_id = école principale de l'enseignant, sinon nil
      def actor_for(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #actor_for"
      end
    end
  end
end
