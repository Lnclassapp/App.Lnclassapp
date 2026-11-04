# 🧠 DOMAINE · Ports::Identity::UserRepositoryPort
# Rôle : contrat de lecture des comptes et de leur PIN (bcrypt côté repository) ; anonymisation d'un compte
# ADR  : 0026, 0028, 0036, 0050, 0055, 0082, 0084, 0094, chargement-automatique-des-lecons-hors-production
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

      # ADR-0082 §4.3, ADR-0084 §4.6 : heure de la dernière ouverture de Lnclass par canal, :pwa (l'app installée depuis
      # le navigateur) ou :android (l'app « Lnclass » du Play Store). Un autre canal lève KeyError. → true
      def mark_app_opened(user_id:, at:, channel: :pwa)
        raise NotImplementedError, "#{self.class} doit implémenter #mark_app_opened"
      end

      # → Entities::Identity::Actor | nil (compte anonymisé : il n'agit plus, comme un visiteur) ; school_id d'un enseignant = current_school_id s'il y est rattaché, sinon son école
      # principale, sinon nil (ADR-0094 §4.2) ; current_school_id est ignoré pour les autres rôles
      def actor_for(user_id:, current_school_id: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #actor_for"
      end

      # Le plus ancien membre actif de l'équipe (compte non anonymisé), auteur des chargements automatiques. → Entities::Identity::Actor | nil
      def oldest_active_team_actor
        raise NotImplementedError, "#{self.class} doit implémenter #oldest_active_team_actor"
      end
    end
  end
end
