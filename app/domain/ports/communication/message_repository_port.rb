# 🧠 DOMAINE · Ports::Communication::MessageRepositoryPort
# Rôle : contrat des annonces : lecture par public_id, écriture avec leurs classes ciblées, rejets, publication du job, plafond
# ADR  : 0045, 0078, 0081
module Ports
  module Communication
    # Gelé au Lot 0 : les lots A, B et C le consomment, aucun ne le redéfinit.
    module MessageRepositoryPort
      # Avec ses classes ciblées (classroom_ids triés). → Entities::Communication::Message | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # message : Message sans id ; son public_id est tiré ici s'il est nil. Écrit ses classes ciblées dans la même
      # transaction (une classe inconnue n'écrit rien). → Message persisté (id, public_id)
      def create(message:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # Réécrit la ligne d'id message.id, sauf son auteur et son public_id, et remplace ses classes ciblées. Une ligne
      # déjà figée en base (archivée ou retirée) n'est jamais réécrite, même par une écriture lue avant son gel
      # (ADR-0078 §4.2). → Message | nil (déjà figée : rien n'est écrit)
      def update(message:)
        raise NotImplementedError, "#{self.class} doit implémenter #update"
      end

      # Efface les rejets de l'annonce : modifier une annonce publiée la rend à ceux qui l'avaient masquée (ADR-0078
      # §4.1). → Integer (rejets effacés)
      def clear_dismissals(message_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #clear_dismissals"
      end

      # Annonces programmées dont l'heure est venue (published_at <= now), les plus anciennes d'abord. → [Message]
      def due_for_publication(now:)
        raise NotImplementedError, "#{self.class} doit implémenter #due_for_publication"
      end

      # Rôle du compte auteur, lu sur users.role : rien ne le stocke sur l'annonce (officielle, retirable).
      # → :team | :school_admin | :teacher | :student
      def author_role(message:)
        raise NotImplementedError, "#{self.class} doit implémenter #author_role"
      end

      # ADR-0081 §4.1 (Lot 0 d'annonces-v2). À appeler DANS la transaction de l'appelant, celle de la parution : verrouille
      # la ligne users de l'auteur (SELECT … FOR NO KEY UPDATE, phase 5) jusqu'à sa fin, puis lit ses annonces en ligne.
      # Deux parutions du même auteur se suivent donc ; une ligne qui le référence (journal d'audit) s'écrit toujours. En ligne = published et now < ends_at (published_at n'est pas comparé : une
      # parution qui a lu son horloge avant le verrou compte celle qui vient d'avoir lieu) ; brouillon, programmée,
      # archivée, retirée et terminée ne comptent pas. → [Message] avec leurs classes, la plus ancienne d'abord
      # (published_at, puis id)
      def live_of(author_id:, now:)
        raise NotImplementedError, "#{self.class} doit implémenter #live_of"
      end

      # Phase 5 d'annonces-v2 (F2), pour le job, dans la transaction de la parution et sous le verrou de l'auteur : passe en
      # published l'annonce d'id donné si elle est encore programmée et due (published_at <= now), en une écriture
      # conditionnelle qui ne touche à aucune autre colonne ; ce qui a changé depuis sa lecture reste.
      # → Message publiée, avec ses classes | nil (plus programmée, ou pas encore due : rien n'est écrit)
      def publish_scheduled(id:, now:)
        raise NotImplementedError, "#{self.class} doit implémenter #publish_scheduled"
      end
    end
  end
end
