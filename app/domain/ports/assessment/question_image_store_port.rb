# 🧠 DOMAINE · Ports::Assessment::QuestionImageStorePort
# Rôle : contrat du stockage de l'image d'une question (service Active Storage, bucket en production) : envoyer, servir, purger
# ADR  : 0047, 0060, 0105
module Ports
  module Assessment
    module QuestionImageStorePort
      StoredImage = Data.define(:public_id, :width, :height)
      # exercise_public_id : l'exercice de la question qui porte l'image, nil tant qu'aucun enregistrement ne la rattache.
      ImageState = Data.define(:content_type, :exercise_public_id)

      # Une nouvelle image, rattachée à aucune question. data : octets déjà vérifiés et sans métadonnées. → StoredImage
      def store(data:, content_type:, width:, height:)
        raise NotImplementedError, "#{self.class} doit implémenter #store"
      end

      # Le format et l'exercice, sans lire le fichier (une requête). → ImageState | nil
      def find(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find"
      end

      # Les octets du fichier, lus sur le service. → String | nil (image inconnue)
      def download(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #download"
      end

      # Supprime les images rattachées à aucune question et envoyées avant before, fichier compris. → nombre supprimé
      def purge_orphans(before:)
        raise NotImplementedError, "#{self.class} doit implémenter #purge_orphans"
      end
    end
  end
end
