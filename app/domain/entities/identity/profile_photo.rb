# 🧠 DOMAINE · Entities::Identity::ProfilePhoto
# Rôle : règles d'une photo de profil : JPEG, PNG ou WebP, 1 Mo et 1024 px de côté au plus (recadrée à 512 px par le navigateur)
# ADR  : 0060
module Entities
  module Identity
    module ProfilePhoto
      CONTENT_TYPES = { jpeg: "image/jpeg", png: "image/png", webp: "image/webp" }.freeze
      MAX_MEGABYTES = 1
      MAX_BYTES = MAX_MEGABYTES * 1024 * 1024
      MAX_SIDE = 1024
    end
  end
end
