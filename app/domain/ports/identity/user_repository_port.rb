# 🧠 DOMAINE · Ports::Identity::UserRepositoryPort
# Rôle : contrat de lecture des comptes et de leur PIN (bcrypt côté repository)
# ADR  : 0026, 0028, 0050, 0055, 0065, 0066
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

      # → Entities::Identity::Actor ; school_id = école principale de l'enseignant ; pour un school_admin, school_id et
      # position viennent de son rattachement actif (school_staffs) à un établissement `active`, sinon tous deux nil
      def actor_for(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #actor_for"
      end

      # Élève non anonymisé ; égalité stricte sur le matricule déjà normalisé, jamais de LIKE (ADR-0065).
      # → Entities::Identity::User | nil
      def find_student_by_number(student_number:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_student_by_number"
      end

      # → Shared::Result : success | :conflict (errors { student_number: [:taken] }) si un autre compte le porte
      def update_student_number(user_id:, student_number:)
        raise NotImplementedError, "#{self.class} doit implémenter #update_student_number"
      end
    end
  end
end
