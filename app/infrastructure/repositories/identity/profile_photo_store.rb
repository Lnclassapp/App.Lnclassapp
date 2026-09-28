# 🔌 INFRA · Repositories::Identity::ProfilePhotoStore
# Rôle : photo de profil en pièce jointe du compte, sur le service Active Storage (bucket) ; remplacer ou retirer efface le fichier
# ADR  : 0047, 0060
module Repositories
  module Identity
    class ProfilePhotoStore
      include Ports::Identity::ProfilePhotoStorePort

      EXTENSIONS = { "image/jpeg" => "jpg", "image/png" => "png", "image/webp" => "webp" }.freeze

      # Le domaine a déjà lu le format dans les octets : pas d'identification, et le blob naît analysé, sans quoi
      # AnalyzeJob chercherait libvips, absent en production. L'ancien fichier part par purge_later (remplacement).
      def attach(user_id:, data:, content_type:)
        photo(user_id).attach(io: StringIO.new(data), filename: "photo.#{EXTENSIONS.fetch(content_type)}", content_type:,
                              identify: false, metadata: { analyzed: true })
        true
      end

      def attached?(user_id:) = photo(user_id).attached?

      # purge, pas purge_later : le fichier disparaît du bucket avant la réponse.
      def remove(user_id:)
        attachment = photo(user_id)
        return false unless attachment.attached?

        attachment.purge
        true
      end

      def read(user_id:)
        attachment = photo(user_id)
        StoredPhoto.new(content_type: attachment.content_type, data: attachment.download) if attachment.attached?
      end

      private

      def photo(user_id) = Orm::User.find(user_id).photo
    end
  end
end
