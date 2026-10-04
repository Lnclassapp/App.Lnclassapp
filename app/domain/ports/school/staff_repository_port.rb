# 🧠 DOMAINE · Ports::School::StaffRepositoryPort
# Rôle : contrat du rattachement d'un compte de direction à son établissement (un seul par compte), de son arrivée à son archivage
# ADR  : 0065, 0077
module Ports
  module School
    module StaffRepositoryPort
      # Écrit dans la transaction de l'acceptation de l'invitation ; joined_via « invitation ». → true
      def attach(user_id:, school_id:, invited_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach"
      end

      # Inscription par le code : verrouille l'établissement, compte ses directions actives arrivées par le code et rattache
      # sous le plafond. → true | false (plafond atteint, rien n'est écrit)
      def attach_by_code(user_id:, school_id:, cap:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach_by_code"
      end

      # → Entities::School::Staff | nil, archivé ou non
      def find_by_user_id(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_user_id"
      end

      # public_id du compte (users.public_id). → Entities::School::Staff | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # → true | false (déjà archivé ou absent : rien n'est écrit)
      def archive(user_id:, by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #archive"
      end

      # Sous le même verrou que attach_by_code ; une arrivée par l'invitation se restaure toujours.
      # → :restored | :not_archived | :cap_reached
      def restore(user_id:, cap:)
        raise NotImplementedError, "#{self.class} doit implémenter #restore"
      end

      # → [Entities::School::Staff] archivés strictement avant `at`
      def archived_before(at:)
        raise NotImplementedError, "#{self.class} doit implémenter #archived_before"
      end

      # Supprime le rattachement (tâche de suppression à J+30). → true
      def delete(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete"
      end
    end
  end
end
