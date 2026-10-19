# 🧠 DOMAINE · Ports::School::StaffRepositoryPort
# Rôle : contrat du rattachement d'un compte de direction à son établissement (un seul par compte), de son arrivée à son archivage
# ADR  : 0065, 0077, 0092 · un seul chef d'établissement actif : vérifié sous le verrou de l'établissement, l'index tranche
module Ports
  module School
    module StaffRepositoryPort
      # Écrit dans la transaction de l'acceptation de l'invitation ; joined_via « invitation », position : une valeur de
      # Entities::School::StaffPosition::ALL. → :attached | :head_taken (un autre chef actif, rien n'est écrit)
      def attach(user_id:, school_id:, invited_by_id:, position:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach"
      end

      # Inscription par le code : verrouille l'établissement, compte ses directions actives arrivées par le code et rattache
      # sous le plafond. → :attached | :cap_reached | :head_taken (rien n'est écrit dans les deux derniers cas)
      def attach_by_code(user_id:, school_id:, cap:, position:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach_by_code"
      end

      # Un chef d'établissement actif, autre que except_user_id, dans cet établissement ? Lecture sans verrou, pour le message ;
      # les écritures le revérifient sous le verrou. → true | false
      def head_taken?(school_id:, except_user_id: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #head_taken?"
      end

      # L'équipe change la fonction d'une direction active, sous le verrou de l'établissement.
      # → [:set, ancienne_fonction] (lue sous le verrou, pour le journal) | :unchanged (même fonction) | :head_taken | :not_found (absent ou archivé)
      def set_position(user_id:, position:)
        raise NotImplementedError, "#{self.class} doit implémenter #set_position"
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

      # Sous le même verrou que attach_by_code ; une arrivée par l'invitation se restaure sous la seule règle du chef unique.
      # → :restored | :not_archived | :cap_reached | :head_taken (un autre chef est actif, ADR-0092 §4.3)
      def restore(user_id:, cap:)
        raise NotImplementedError, "#{self.class} doit implémenter #restore"
      end

      # → [Entities::School::Staff] archivés strictement avant `at`
      def archived_before(at:)
        raise NotImplementedError, "#{self.class} doit implémenter #archived_before"
      end

      # Dans la transaction de la suppression à J+30 : verrouille l'établissement et relit le rattachement. Une restauration
      # validée entre-temps le sort de la suppression. → true (toujours archivé avant `before`) | false
      def claim_for_purge(user_id:, before:)
        raise NotImplementedError, "#{self.class} doit implémenter #claim_for_purge"
      end

      # Supprime le rattachement (tâche de suppression à J+30). → true
      def delete(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete"
      end
    end
  end
end
