# 🧠 DOMAINE · Ports::Communication::ArticleImageStorePort
# Rôle : contrat du stockage des images d'article (service Active Storage, bucket en production) : envoyer, servir, purger
# ADR  : 0047, 0060, 0073
module Ports
  module Communication
    module ArticleImageStorePort
      # sgid : l'identifiant signé que cite le texte (pièce jointe Action Text) ; public_id : l'adresse de l'image.
      StoredImage = Data.define(:public_id, :sgid, :width, :height)
      # article_status : "draft", "published", "archived", ou nil pour une image rattachée à aucun article.
      ServedImage = Data.define(:content_type, :data, :article_status)

      # Une nouvelle image, rattachée à aucun article. data : octets déjà vérifiés et sans métadonnées
      # (Dtos::Communication::ArticleImageInput). → StoredImage
      def store(data:, content_type:, width:, height:)
        raise NotImplementedError, "#{self.class} doit implémenter #store"
      end

      # → ServedImage | nil
      def read(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #read"
      end

      # Supprime les images rattachées à aucun article et envoyées avant before, et purge leur fichier. → nombre supprimé
      def purge_orphans(before:)
        raise NotImplementedError, "#{self.class} doit implémenter #purge_orphans"
      end
    end
  end
end
