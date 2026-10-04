# 🧠 DOMAINE · Ports::Communication::MessageRepositoryPort
# Rôle : contrat des annonces : lecture par public_id, écriture avec leurs classes ciblées, rejets, publication programmée
# ADR  : 0045, 0078
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
    end
  end
end
