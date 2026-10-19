# 🧠 DOMAINE · Ports::Catalog::EssentialImageStorePort
# Rôle : contrat du stockage des images de fiche (service Active Storage, bucket en production) : envoyer, compter, servir, purger
# ADR  : 0047, 0060, 0105
module Ports
  module Catalog
    module EssentialImageStorePort
      # sgid : l'identifiant signé que cite le texte de la fiche (pièce jointe Action Text) ; public_id : l'adresse de l'image.
      StoredImage = Data.define(:public_id, :sgid, :width, :height)
      # essential_slug : la fiche qui cite l'image, nil tant qu'aucun enregistrement ne la cite.
      ImageState = Data.define(:content_type, :essential_slug)

      # Une nouvelle image, rattachée à aucune fiche. data : octets déjà vérifiés et sans métadonnées
      # (Dtos::Shared::ContentImageInput). → StoredImage
      def store(data:, content_type:, width:, height:)
        raise NotImplementedError, "#{self.class} doit implémenter #store"
      end

      # Nombre d'images rattachées à la fiche, pour tenir Shared::ContentImage::MAX_PER_ESSENTIAL. → Integer
      def count_for(essential_slug:)
        raise NotImplementedError, "#{self.class} doit implémenter #count_for"
      end

      # Le format et la fiche, sans lire le fichier (une requête). → ImageState | nil
      def find(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find"
      end

      # Les octets du fichier, lus sur le service. → String | nil (image inconnue)
      def download(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #download"
      end

      # Supprime les images rattachées à aucune fiche et envoyées avant before, fichier compris. → nombre supprimé
      def purge_orphans(before:)
        raise NotImplementedError, "#{self.class} doit implémenter #purge_orphans"
      end
    end
  end
end
