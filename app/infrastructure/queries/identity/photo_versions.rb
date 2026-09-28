# 🔌 INFRA · Queries::Identity::PhotoVersions
# Rôle : version de la photo de chaque compte (empreinte du fichier, en base64 URL), portée par l'adresse de l'image
# ADR  : 0060
module Queries
  module Identity
    module PhotoVersions
      # Colonne à lire après `left_joins(photo_attachment: :blob)` sur Orm::User.
      CHECKSUM = "active_storage_blobs.checksum".freeze

      module_function

      # → { user_id => version } des seuls comptes qui ont une photo, en une requête
      def for(user_ids:)
        Orm::User.joins(photo_attachment: :blob).where(id: user_ids).pluck(:id, CHECKSUM).to_h { |id, checksum| [ id, of(checksum) ] }
      end

      # L'empreinte MD5 d'Active Storage, en base64 : une nouvelle photo change l'adresse, donc le cache ne sert jamais l'ancienne.
      def of(checksum) = checksum&.delete("=")&.tr("+/", "-_")
    end
  end
end
