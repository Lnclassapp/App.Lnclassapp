# 🧠 DOMAINE · Ports::Communication::AttachmentStorePort
# Rôle : contrat du stockage de l'image et de l'audio d'une annonce (service Active Storage, bucket en production)
# ADR  : 0045, 0047, 0078
module Ports
  module Communication
    # kind : :image ou :audio (une chaîne est acceptée), un fichier de chaque au plus par annonce ; tout autre kind lève
    # ArgumentError. Les octets arrivent déjà vérifiés par le domaine (type lu dans le contenu, taille).
    module AttachmentStorePort
      # range : la plage d'octets servie (incluse), nil quand le fichier est lu en entier ; byte_size : la taille du fichier.
      StoredFile = Data.define(:content_type, :data, :byte_size, :range)

      # Remplace le fichier existant de ce kind, dont le fichier est effacé. → true
      def attach(message_id:, kind:, io:, content_type:, filename:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach"
      end

      # Efface le fichier du stockage, pas seulement le lien. → true si un fichier a été retiré, false sinon
      def remove(message_id:, kind:)
        raise NotImplementedError, "#{self.class} doit implémenter #remove"
      end

      # → Boolean
      def attached?(message_id:, kind:)
        raise NotImplementedError, "#{self.class} doit implémenter #attached?"
      end

      # range : nil (tout le fichier) ou une plage d'octets, lue seule : 0..1023, 0...1024, 500.. (jusqu'à la fin), -500..
      # (les 500 derniers octets, comme String#byteslice) ; une fin au-delà du fichier s'arrête à son dernier octet. Une
      # plage hors du fichier est ignorée (lecture entière, range nil), comme HTTP le permet. → StoredFile | nil
      def read(message_id:, kind:, range: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #read"
      end
    end
  end
end
