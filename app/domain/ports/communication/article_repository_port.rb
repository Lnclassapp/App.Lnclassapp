# 🧠 DOMAINE · Ports::Communication::ArticleRepositoryPort
# Rôle : contrat de persistance des articles du blog : écrire, changer d'état, compter une lecture
# ADR  : 0026, 0029, 0035, 0073
module Ports
  module Communication
    module ArticleRepositoryPort
      # Tous états. → Entities::Communication::Article | nil. cover : ArticleImage (sans alt : celui de la couverture est
      # Article#cover_alt) | nil ; images : les images que cite le texte, dans l'ordre du texte, chacune avec son alt.
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Un brouillon de author_id, horodaté at, dont le slug suit le titre (-2, -3… ; figé). dto : Dtos::Communication::
      # ArticleInput valide. Dans la transaction : le texte est assaini, la couverture et les images qu'il cite sont
      # rattachées à l'article, avec leurs textes de remplacement (dto.image_alts).
      # → Result(Article) | failure(:invalid, errors: { cover_public_id: [:invalid] }) (couverture inconnue ou d'un autre article)
      #   | failure(:invalid, errors: { body: [:image_unreadable] }) (pièce jointe au sgid illisible : rien n'est écrit)
      #   | failure(:conflict, errors: { base: [:write_failed] }) (slug pris deux fois de suite par des créations simultanées)
      def create(dto:, author_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # Titre, résumé, texte, signature, couverture et textes de remplacement ; slug et état inchangés. Comme create, et
      # les images rattachées que l'article ne cite plus (ni texte ni couverture) sont supprimées, leur fichier purgé
      # après validation. → Result(Article) | les mêmes échecs :invalid que create (un sgid illisible ne détruit aucune image).
      def update(id:, dto:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #update"
      end

      # to : "published" (published_at = COALESCE(published_at, at), archived_at = NULL) ou "archived" (archived_at = at).
      # La transition est déjà admise par Entities::Communication::Article::TRANSITIONS pour l'état lu ; elle ne s'écrit
      # que si l'article est encore dans un état de départ admis pour to. → true si l'article a changé d'état ; false
      # sinon (un geste concurrent l'a déjà fait : rien n'est réécrit)
      def transition(id:, to:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #transition"
      end

      # Une requête, sans transaction ni verrou ; updated_at intact. → true si la lecture est comptée, false si l'article
      # n'est pas publié
      def increment_reads(article_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #increment_reads"
      end
    end
  end
end
