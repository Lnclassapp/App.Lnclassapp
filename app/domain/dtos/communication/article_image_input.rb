# 🧠 DOMAINE · Dtos::Communication::ArticleImageInput
# Rôle : l'image d'article envoyée : format lu dans les octets (JPEG, PNG, WebP fixe), 1 Mo et 1600 px au plus ; octets gardés sans métadonnées
# ADR  : 0060, 0073 · UDR : 0065
module Dtos
  module Communication
    # Calqué sur Dtos::Identity::ProfilePhotoInput, avec les plafonds de Entities::Communication::ArticleImage.
    class ArticleImageInput
      include ActiveModel::Model

      IMAGE = Entities::Communication::ArticleImage
      HEADER = Entities::Shared::ImageHeader
      # Des images que Lnclass reconnaît sans les accepter : GIF, WebP animé, HEIC/AVIF d'un téléphone, SVG. Leur
      # raison est le format ; tout autre fichier que ImageHeader ne lit pas est « illisible ».
      OTHER_FORMATS = [ /\AGIF8[79]a/n, /\ARIFF.{4}WEBP.*ANIM/mn, /\A.{4}ftyp(heic|heix|hevc|mif1|msf1|avif)/mn,
                        /\A\s*(<\?xml|<svg)/n ].freeze

      # file : tout objet qui répond à read, rewind et size (fichier téléversé, StringIO), ou nil.
      attr_accessor :file

      validate :file_is_an_article_image

      # Valides seulement après valid? : le format, les dimensions et les octets gardés (sans Exif, XMP ni IPTC).
      def content_type = "image/#{facts.format}"
      def width = facts.width
      def height = facts.height
      def data = @data ||= HEADER.strip(bytes)
      def byte_size = data.bytesize

      private

      # Le poids est vérifié avant toute lecture : un fichier de plusieurs Mo n'est jamais chargé en mémoire.
      def file_is_an_article_image
        return errors.add(:file, :blank) if file.nil?
        return errors.add(:file, :too_heavy, count: IMAGE::MAX_MEGABYTES) if file.size > IMAGE::MAX_BYTES
        # Fail closed : un flux incomplet ou mal formé n'est pas une image, et les octets gardés sont relus sans métadonnées.
        return errors.add(:file, other_format? ? :content_type : :unreadable) if facts.nil? || HEADER.read(data)&.metadata != false

        errors.add(:file, :too_large, count: IMAGE::MAX_SIDE) if [ width, height ].max > IMAGE::MAX_SIDE
      end

      def other_format? = OTHER_FORMATS.any? { bytes.match?(it) }

      def facts = @facts ||= HEADER.read(bytes)

      def bytes
        @bytes ||= begin
          file.rewind
          file.read.b
        end
      end
    end
  end
end
