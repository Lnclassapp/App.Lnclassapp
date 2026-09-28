# 🧠 DOMAINE · Entities::Identity::ImageHeader
# Rôle : lit l'en-tête d'une image JPEG, PNG ou WebP sans bibliothèque (format réel, dimensions, métadonnées) et retire ses métadonnées
# ADR  : 0060
module Entities
  module Identity
    module ImageHeader
      Facts = Data.define(:format, :width, :height, :metadata)
      # Une partie du fichier : segment JPEG, chunk PNG ou WebP. at : son premier octet ; size : sa longueur totale.
      Part = Data.define(:type, :at, :size)

      JPEG_SIGNATURE = "\xFF\xD8".b.freeze
      PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
      VP8_START_CODE = "\x9D\x01\x2A".b.freeze
      # Segments d'image SOF0 à SOF15, sauf DHT (C4), JPG (C8) et DAC (CC) : hauteur puis largeur.
      JPEG_FRAMES = ((0xC0..0xCF).to_a - [ 0xC4, 0xC8, 0xCC ]).freeze
      JPEG_SCAN = 0xDA
      # APP1 (Exif, XMP) et APP13 (IPTC) : lieu, appareil, date de prise de vue.
      JPEG_METADATA = [ 0xE1, 0xED ].freeze
      PNG_METADATA = %w[eXIf iTXt tEXt zTXt].freeze
      WEBP_METADATA = [ "EXIF", "XMP " ].freeze
      # Drapeaux Exif (0x08) et XMP (0x04) de l'en-tête étendu VP8X.
      WEBP_METADATA_FLAGS = 0x0C

      module_function

      # bytes : String → Facts | nil (ni JPEG, ni PNG, ni WebP, ou en-tête tronqué)
      def read(bytes)
        bytes = bytes.to_s.b
        case format_of(bytes)
        when :jpeg then jpeg(bytes)
        when :png then png(bytes)
        when :webp then webp(bytes)
        end
      end

      # Les mêmes octets sans les segments ou chunks de métadonnées ; tout autre fichier est rendu tel quel.
      def strip(bytes)
        bytes = bytes.to_s.b
        case format_of(bytes)
        when :jpeg then strip_parts(bytes, jpeg_parts(bytes), JPEG_METADATA, head: 2)
        when :png then strip_parts(bytes, png_parts(bytes), PNG_METADATA, head: 8)
        when :webp then strip_webp(bytes)
        else bytes
        end
      end

      def format_of(bytes)
        if bytes.start_with?(JPEG_SIGNATURE) then :jpeg
        elsif bytes.start_with?(PNG_SIGNATURE) then :png
        elsif bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WEBP" then :webp
        end
      end

      def jpeg(bytes)
        parts = jpeg_parts(bytes)
        frame = parts.find { JPEG_FRAMES.include?(it.type) }
        height, width = fields(bytes, frame.at + 5, "nn", 4) if frame
        facts(:jpeg, [ width, height ], parts, JPEG_METADATA)
      end

      def png(bytes)
        size = fields(bytes, 16, "NN", 8) if bytes.byteslice(12, 4) == "IHDR"
        facts(:png, size, png_parts(bytes), PNG_METADATA)
      end

      def webp(bytes)
        parts = webp_parts(bytes)
        facts(:webp, parts.lazy.filter_map { webp_size(bytes, it) }.first, parts, WEBP_METADATA)
      end

      # Taille lue dans l'en-tête étendu (VP8X), sans perte (VP8L) ou avec perte (VP8 ).
      def webp_size(bytes, part)
        data = part.at + 8
        case part.type
        when "VP8X"
          width_low, width_high, height_low, height_high = fields(bytes, data + 4, "vCvC", 6)
          [ width_low + (width_high << 16) + 1, height_low + (height_high << 16) + 1 ] if height_high
        when "VP8L"
          signature, bits = fields(bytes, data, "CV", 5)
          [ (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1 ] if signature == 0x2F
        when "VP8 "
          fields(bytes, data + 6, "vv", 4)&.map { it & 0x3FFF } if bytes.byteslice(data + 3, 3) == VP8_START_CODE
        end
      end

      def facts(format, size, parts, metadata_types)
        width, height = size
        return unless size&.all? { it.to_i.positive? }

        Facts.new(format:, width:, height:, metadata: parts.any? { metadata_types.include?(it.type) })
      end

      # Segments d'en-tête, du premier après SOI jusqu'au début du scan (exclu) ; s'arrête sur un octet hors segment.
      def jpeg_parts(bytes)
        walk(2) do |at|
          prefix, marker, length = fields(bytes, at, "CCn", 4)
          Part.new(type: marker, at:, size: 2 + length) if prefix == 0xFF && marker != JPEG_SCAN
        end
      end

      # Chunk PNG : longueur, type, données, CRC.
      def png_parts(bytes)
        walk(8) { |at| fields(bytes, at, "Na4", 8)&.then { |length, type| Part.new(type:, at:, size: 12 + length) } }
      end

      # Chunk RIFF : type, longueur, données, un octet de bourrage après une longueur impaire.
      def webp_parts(bytes)
        walk(12) { |at| fields(bytes, at, "a4V", 8)&.then { |type, length| Part.new(type:, at:, size: 8 + length + (length % 2)) } }
      end

      # Parties successives tant que le bloc en lit une ; chaque partie avance d'au moins deux octets.
      def walk(at)
        parts = []
        while (part = yield(at))
          parts << part
          at += part.size
        end
        parts
      end

      # Garde l'en-tête du fichier, les parties hors métadonnées, puis tout ce qui suit la dernière partie (le scan JPEG).
      def strip_parts(bytes, parts, metadata_types, head:)
        tail = parts.empty? ? head : parts.last.at + parts.last.size
        kept = parts.reject { metadata_types.include?(it.type) }.map { bytes.byteslice(it.at, it.size) }
        [ bytes.byteslice(0, head), *kept, bytes.byteslice(tail..) ].join.b
      end

      # Le conteneur RIFF annonce sa longueur, et VP8X la présence d'Exif et de XMP : les deux sont recalculés.
      def strip_webp(bytes)
        body = strip_parts(bytes, webp_parts(bytes), WEBP_METADATA, head: 12)
        flags = body.getbyte(20)
        body.setbyte(20, flags & ~WEBP_METADATA_FLAGS) if flags && body.byteslice(12, 4) == "VP8X"
        body[4, 4] = [ body.bytesize - 8 ].pack("V")
        body
      end

      def fields(bytes, at, directive, length)
        slice = bytes.byteslice(at, length)
        slice.unpack(directive) if slice&.bytesize == length
      end
    end
  end
end
