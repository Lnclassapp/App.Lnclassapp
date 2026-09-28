# 🧠 DOMAINE · Dtos::Identity::ProfilePhotoInput
# Rôle : la photo téléversée : format lu dans les octets (JPEG, PNG, WebP), 1 Mo et 1024 px au plus ; octets gardés sans métadonnées
# ADR  : 0060
module Dtos
  module Identity
    class ProfilePhotoInput
      include ActiveModel::Model

      PHOTO = Entities::Identity::ProfilePhoto
      HEADER = Entities::Identity::ImageHeader

      # photo : tout objet qui répond à read, rewind et size (fichier téléversé, StringIO), ou nil.
      attr_accessor :photo

      validate :photo_is_a_small_image

      # Valides seulement après valid? : le format, les dimensions et les octets gardés (sans Exif, XMP ni IPTC).
      def content_type = PHOTO::CONTENT_TYPES.fetch(facts.format)
      def width = facts.width
      def height = facts.height
      def data = @data ||= HEADER.strip(bytes)
      def byte_size = data.bytesize

      private

      # Le poids est vérifié avant toute lecture : un fichier de plusieurs Mo n'est jamais chargé en mémoire.
      def photo_is_a_small_image
        return errors.add(:photo, :blank) if photo.nil?
        return errors.add(:photo, :too_large, count: PHOTO::MAX_MEGABYTES) if photo.size > PHOTO::MAX_BYTES
        return errors.add(:photo, :unsupported) if facts.nil?

        errors.add(:photo, :too_wide, count: PHOTO::MAX_SIDE) if [ width, height ].max > PHOTO::MAX_SIDE
      end

      def facts = @facts ||= HEADER.read(bytes)

      def bytes
        @bytes ||= begin
          photo.rewind
          photo.read.b
        end
      end
    end
  end
end
