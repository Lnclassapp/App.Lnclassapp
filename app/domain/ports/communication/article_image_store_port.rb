# 🧠 DOMAINE · Ports::Communication::ArticleImageStorePort
# Rôle : contrat du stockage des images d'article (service Active Storage, bucket en production) : envoyer, servir, purger
# ADR  : 0047, 0060, 0073
module Ports
  module Communication
    module ArticleImageStorePort
      # sgid : l'identifiant signé que cite le texte (pièce jointe Action Text) ; public_id : l'adresse de l'image.
      StoredImage = Data.define(:public_id, :sgid, :width, :height)
      # article_status : "draft", "published", "archived", ou nil pour une image rattachée à aucun article.
      ImageState = Data.define(:content_type, :article_status)

      # Une nouvelle image, rattachée à aucun article. data : octets déjà vérifiés et sans métadonnées
      # (Dtos::Communication::ArticleImageInput). → StoredImage
      def store(data:, content_type:, width:, height:)
        raise NotImplementedError, "#{self.class} doit implémenter #store"
      end

      # Le format et l'état de l'article, sans lire le fichier (une requête). → ImageState | nil
      def find(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find"
      end

      # Les octets du fichier, lus sur le service (le bucket en production). → String | nil (image inconnue)
      def download(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #download"
      end

      # Supprime les images rattachées à aucun article et envoyées avant before, et purge leur fichier. → nombre supprimé
      def purge_orphans(before:)
        raise NotImplementedError, "#{self.class} doit implémenter #purge_orphans"
      end
    end
  end
end
