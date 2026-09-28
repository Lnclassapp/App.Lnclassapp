# 🧠 DOMAINE · Entities::Identity::ImageHeader
# Rôle : lit une image JPEG, PNG ou WebP entière sans bibliothèque (format réel, dimensions, métadonnées) et retire ses métadonnées
# ADR  : 0060
module Entities
  module Identity
    # Fail closed : un fichier n'est une image que si tout son flux est bien formé — le JPEG jusqu'à EOI, le PNG jusqu'à
    # IEND avec des CRC justes, le WebP dans sa longueur RIFF. Sinon read rend nil : aucune partie du fichier ne peut
    # échapper à la lecture, donc au retrait des métadonnées.
    module ImageHeader
      Facts = Data.define(:format, :width, :height, :metadata)
      # Une partie du fichier : segment JPEG, chunk PNG ou WebP. at : son premier octet (remplissage compris) ; size : sa
      # longueur totale ; data : le premier octet après le marqueur, ou après l'en-tête du chunk.
      Part = Data.define(:type, :at, :size, :data)

      JPEG_SIGNATURE = "\xFF\xD8".b.freeze
      PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
      VP8_START_CODE = "\x9D\x01\x2A".b.freeze
      # Segments d'image SOF0 à SOF15, sauf DHT (C4), JPG (C8) et DAC (CC) : hauteur puis largeur.
      JPEG_FRAMES = ((0xC0..0xCF).to_a - [ 0xC4, 0xC8, 0xCC ]).freeze
      JPEG_SCAN = 0xDA
      JPEG_END = 0xD9
      # Hors d'un scan : 0x00, TEM, RSTn ou un second SOI ne sont pas des marqueurs de segment.
      JPEG_UNEXPECTED = [ 0x00, 0x01, *(0xD0..0xD8) ].freeze
      # APPn gardés : JFIF (APP0), profil ICC (APP2), Adobe (APP14). Tout autre APPn et les commentaires (COM) partent.
      JPEG_KEPT_APPS = [ 0xE0, 0xE2, 0xEE ].freeze
      JPEG_COMMENT = 0xFE
      PNG_METADATA = %w[eXIf iTXt tEXt zTXt].freeze
      WEBP_METADATA = [ "EXIF", "XMP " ].freeze
      WEBP_IMAGES = [ "VP8 ", "VP8L" ].freeze
      # Drapeaux Exif (0x08) et XMP (0x04) de l'en-tête étendu VP8X.
      WEBP_METADATA_FLAGS = 0x0C

      module_function

      # bytes : String → Facts | nil (ni JPEG, ni PNG, ni WebP, ou flux incomplet ou mal formé)
      def read(bytes)
        bytes = bytes.to_s.b
        case format_of(bytes)
        when :jpeg then jpeg(bytes)
        when :png then png(bytes)
        when :webp then webp(bytes)
        end
      end

      # Les mêmes octets sans les segments ou chunks de métadonnées. Un fichier illisible est rendu tel quel : read l'a
      # déjà refusé, il n'est jamais stocké.
      def strip(bytes)
        bytes = bytes.to_s.b
        parts = parts_of(bytes)
        return bytes if parts.nil?

        kept = parts.reject { metadata?(bytes, it) }.map { bytes.byteslice(it.at, it.size) }
        stripped = [ bytes.byteslice(0, parts.first.at), *kept ].join.b
        format_of(bytes) == :webp ? fix_webp(stripped) : stripped
      end

      def format_of(bytes)
        if bytes.start_with?(JPEG_SIGNATURE) then :jpeg
        elsif bytes.start_with?(PNG_SIGNATURE) then :png
        elsif bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WEBP" then :webp
        end
      end

      def parts_of(bytes)
        case format_of(bytes)
        when :jpeg then jpeg_parts(bytes)
        when :png then png_parts(bytes)
        when :webp then webp_parts(bytes)
        end
      end

      def metadata?(bytes, part)
        case format_of(bytes)
        when :jpeg then part.type == JPEG_COMMENT || ((0xE0..0xEF).cover?(part.type) && !JPEG_KEPT_APPS.include?(part.type))
        when :png then PNG_METADATA.include?(part.type)
        else WEBP_METADATA.include?(part.type)
        end
      end

      # Le premier SOF, avant le premier scan, donne la taille.
      def jpeg(bytes)
        parts = jpeg_parts(bytes)
        return if parts.nil?

        frame = parts.index { JPEG_FRAMES.include?(it.type) }
        scan = parts.index { it.type == JPEG_SCAN }
        return unless frame && scan && frame < scan

        height, width = fields(bytes, parts[frame].data + 3, "nn", 4)
        facts(bytes, :jpeg, [ width, height ], parts)
      end

      def png(bytes)
        parts = png_parts(bytes)
        facts(bytes, :png, fields(bytes, parts.first.data, "NN", 8), parts) if parts
      end

      # Une seule image (VP8 ou VP8L) : une animation n'est pas une photo. L'en-tête étendu, s'il existe, vient en premier
      # et donne la taille ; sinon, l'image la donne.
      def webp(bytes)
        parts = webp_parts(bytes)
        return if parts.nil?

        images = parts.select { WEBP_IMAGES.include?(it.type) }
        extended = parts.index { it.type == "VP8X" }
        return unless images.one? && extended.to_i.zero?

        facts(bytes, :webp, webp_size(bytes, extended ? parts.first : images.first), parts)
      end

      # Taille lue dans l'en-tête étendu (VP8X), sans perte (VP8L) ou avec perte (VP8 ), toujours dans le chunk lui-même.
      def webp_size(bytes, part)
        payload = bytes.byteslice(part.data, part.size - 8)
        case part.type
        when "VP8X"
          width_low, width_high, height_low, height_high = fields(payload, 4, "vCvC", 6)
          [ width_low + (width_high << 16) + 1, height_low + (height_high << 16) + 1 ] if height_high
        when "VP8L"
          signature, bits = fields(payload, 0, "CV", 5)
          [ (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1 ] if signature == 0x2F
        else vp8_size(payload)
        end
      end

      # Image clé seulement, dont la première partition tient dans le chunk.
      def vp8_size(payload)
        low, high = fields(payload, 0, "vC", 3)
        return if high.nil?

        tag = low | (high << 16)
        return unless tag.nobits?(1) && 10 + (tag >> 5) <= payload.bytesize && payload.byteslice(3, 3) == VP8_START_CODE

        fields(payload, 6, "vv", 4).map { it & 0x3FFF }
      end

      def facts(bytes, format, size, parts)
        width, height = size
        return unless size&.all? { it.to_i.positive? }

        Facts.new(format:, width:, height:, metadata: parts.any? { metadata?(bytes, it) })
      end

      # Tout le fichier, segment par segment, scans compris, jusqu'à EOI qui doit le terminer. Octets de remplissage 0xFF
      # acceptés avant un marqueur (T.81 § B.1.1.2) ; tout autre octet hors segment rend le fichier illisible.
      def jpeg_parts(bytes)
        parts = []
        at = 2
        loop do
          return unless bytes.getbyte(at) == 0xFF

          marker_at = at
          marker_at += 1 while bytes.getbyte(marker_at + 1) == 0xFF
          marker = bytes.getbyte(marker_at + 1)
          return if marker.nil? || JPEG_UNEXPECTED.include?(marker)

          stop = jpeg_segment_end(bytes, marker, marker_at + 2)
          return if stop.nil?

          parts << Part.new(type: marker, at:, size: stop - at, data: marker_at + 2)
          return (parts if stop == bytes.bytesize) if marker == JPEG_END

          at = stop
        end
      end

      # Fin du segment : EOI n'a pas de longueur ; un scan continue par ses données entropiques jusqu'au prochain
      # marqueur (0xFF suivi d'autre chose que 0x00, bourrage, ou RSTn, remise à zéro).
      def jpeg_segment_end(bytes, marker, data)
        return data if marker == JPEG_END

        length = fields(bytes, data, "n", 2)&.first
        return unless length && length >= 2 && data + length <= bytes.bytesize
        return data + length unless marker == JPEG_SCAN

        at = data + length
        while (at = bytes.index("\xFF".b, at))
          following = bytes.getbyte(at + 1)
          return at unless following.nil? || following.zero? || (0xD0..0xD7).cover?(following)
          return if following.nil?

          at += 2
        end
      end

      # Chunks PNG (longueur, type, données, CRC) : IHDR d'abord, IDAT au moins, IEND à la toute fin.
      def png_parts(bytes)
        parts = chunks(bytes, 8) do |at|
          length, type = fields(bytes, at, "Na4", 8)
          next unless length && type.match?(/\A[A-Za-z]{4}\z/) && at + 12 + length <= bytes.bytesize
          next unless fields(bytes, at + 8 + length, "N", 4).first == Zlib.crc32(bytes.byteslice(at + 4, 4 + length))

          Part.new(type:, at:, size: 12 + length, data: at + 8)
        end
        parts if parts&.first&.type == "IHDR" && parts.first.size == 25 && parts.last.type == "IEND" &&
                 parts.any? { it.type == "IDAT" }
      end

      # Chunks RIFF (type, longueur, données, bourrage après une longueur impaire), exactement dans la longueur annoncée.
      def webp_parts(bytes)
        return unless fields(bytes, 4, "V", 4).first == bytes.bytesize - 8

        chunks(bytes, 12) do |at|
          type, length = fields(bytes, at, "a4V", 8)
          next if length.nil?

          size = 8 + length + (length % 2)
          Part.new(type:, at:, size:, data: at + 8) if at + size <= bytes.bytesize
        end
      end

      # Parties successives du bloc jusqu'à la fin exacte du fichier ; nil dès qu'une partie est illisible.
      def chunks(bytes, at)
        parts = []
        while at < bytes.bytesize
          part = yield(at)
          return if part.nil?

          parts << part
          at += part.size
        end
        parts
      end

      # Le conteneur RIFF annonce sa longueur, et VP8X la présence d'Exif et de XMP : les deux sont recalculés.
      def fix_webp(body)
        body.setbyte(20, body.getbyte(20) & ~WEBP_METADATA_FLAGS) if body.byteslice(12, 4) == "VP8X"
        body[4, 4] = [ body.bytesize - 8 ].pack("V")
        body
      end

      def fields(bytes, at, directive, length)
        slice = bytes.byteslice(at, length)
        slice.unpack(directive) if slice.to_s.bytesize == length
      end
    end
  end
end
