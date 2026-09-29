# 🧠 DOMAINE · Ports::Identity::ProfilePhotoStorePort
# Rôle : contrat du stockage de la photo de profil (service Active Storage, bucket en production) ; une photo au plus par compte
# ADR  : 0047, 0060
module Ports
  module Identity
    module ProfilePhotoStorePort
      StoredPhoto = Data.define(:content_type, :data)

      # Remplace la photo existante, dont le fichier est effacé. data : octets déjà vérifiés. → true
      def attach(user_id:, data:, content_type:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach"
      end

      # → Boolean
      def attached?(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #attached?"
      end

      # Efface le fichier du stockage, pas seulement le lien. → true si une photo a été retirée, false sinon
      def remove(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #remove"
      end

      # → StoredPhoto | nil
      def read(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #read"
      end
    end
  end
end
