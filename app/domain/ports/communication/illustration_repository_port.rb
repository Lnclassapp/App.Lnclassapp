# 🧠 DOMAINE · Ports::Communication::IllustrationRepositoryPort
# Rôle : contrat de la bibliothèque d'illustrations de l'équipe : lecture, choix des auteurs, ajout sous verrou, renommage, retrait
# ADR  : 0081 · UDR : 0075
module Ports
  module Communication
    # Gelé au Lot 0 d'annonces-v2 : les lots A, B et C le consomment, aucun ne le redéfinit. Une illustration n'est
    # jamais supprimée : retirée, elle sort du choix et reste rendue sur les annonces qui la portent (ADR-0081 §4.3).
    module IllustrationRepositoryPort
      # → Entities::Communication::Illustration | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Le choix des auteurs : les illustrations non retirées, la plus ancienne d'abord (date d'ajout, puis id).
      # → [Illustration]
      def available
        raise NotImplementedError, "#{self.class} doit implémenter #available"
      end

      # Les illustrations de ces ids, retirées comprises, en une requête ; un id inconnu est absent du résultat.
      # → { id => Illustration }
      def find_all_by_ids(ids:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_all_by_ids"
      end

      # illustration : Illustration sans id ; son public_id est tiré ici s'il est nil. Ses formes sont écrites telles
      # quelles : elles arrivent déjà reconstruites par la lecture du SVG. → Illustration persistée (id, public_id)
      def create(illustration:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # Écrit le seul nom. → Illustration | nil (id inconnu)
      def rename(id:, name:)
        raise NotImplementedError, "#{self.class} doit implémenter #rename"
      end

      # Pose retired_at ; une illustration déjà retirée garde sa première date. → Illustration | nil (id inconnu)
      def retire(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #retire"
      end

      # Phase 5 d'annonces-v2 (F3). À appeler DANS la transaction de l'ajout : verrouille la bibliothèque jusqu'à sa fin,
      # sans bloquer sa lecture. Deux ajouts se suivent donc, et le second compte ce que le premier a écrit. → true
      def lock_library
        raise NotImplementedError, "#{self.class} doit implémenter #lock_library"
      end
    end
  end
end
