# 🧠 DOMAINE · Entities::Identity::ImageHeader
# Rôle : lit une image JPEG, PNG ou WebP entière sans bibliothèque (format réel, dimensions, métadonnées) et retire ses métadonnées
# ADR  : 0060
module Entities
  module Identity
    # Fail closed : un fichier n'est une image que si tout son flux est bien formé — le JPEG jusqu'à son premier EOI, le
    # PNG jusqu'à IEND avec des CRC justes, le WebP dans sa longueur RIFF — et si chaque partie gardée a exactement la
    # forme de sa norme (retour du challenger de la PR #65 : aucun octet libre dans une partie gardée). Sinon read rend
    # nil : aucune partie du fichier ne peut échapper à la lecture, donc au retrait des métadonnées.
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
      # Ce qui suit le premier EOI (Motion Photo, image MPF, carte de gain d'un téléphone) : lu comme une partie retirée.
      JPEG_TRAILER = :trailer
      JPEG_DQT = 0xDB
      JPEG_DHT = 0xC4
      JPEG_DAC = 0xCC
      # Liste blanche : seuls les segments et chunks qui dessinent l'image restent, réécrits dans leur forme standard
      # quand ils ont des champs libres. Tout le reste part, quels que soient son nom ou sa signature — un profil ICC
      # (APP2, iCCP, ICCP) aussi : son contenu est libre, il a transporté un secret dans la contre-épreuve de la PR #50.
      # JPEG : SOFn, DHT, DAC, DQT, DRI, DNL, SOS (avec son scan), EOI ; JFIF (APP0) et Adobe (APP14) réécrits.
      JPEG_KEPT = [ *JPEG_FRAMES, JPEG_DHT, JPEG_DAC, JPEG_DQT, 0xDD, 0xDC, JPEG_SCAN, JPEG_END ].freeze
      JPEG_JFIF = 0xE0
      JPEG_ADOBE = 0xEE
      # JFIF 1.01, sans unité, rapport 1:1, sans vignette ; Adobe version 100, drapeaux nuls, puis la transformée d'origine.
      JFIF_SEGMENT = "\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00".b.freeze
      ADOBE_PREFIX = "\xFF\xEE\x00\x0EAdobe\x00\x64\x00\x00\x00\x00".b.freeze
      PNG_KEPT = %w[IHDR PLTE IDAT IEND tRNS gAMA cHRM sRGB].freeze
      # Profondeurs permises par type de couleur (PNG § 11.2.2) ; chunks uniques ; longueur fixe des chunks sans tableau.
      PNG_DEPTHS = { 0 => [ 1, 2, 4, 8, 16 ], 2 => [ 8, 16 ], 3 => [ 1, 2, 4, 8 ], 4 => [ 8, 16 ], 6 => [ 8, 16 ] }.freeze
      PNG_ONCE = %w[IHDR PLTE tRNS gAMA cHRM sRGB IEND].freeze
      PNG_LENGTHS = { "IEND" => 0, "gAMA" => 4, "cHRM" => 32, "sRGB" => 1 }.freeze
      PNG_PALETTE = 3
      # tRNS d'une image en gris (une valeur) ou en couleurs (trois) : des échantillons de 16 bits ; ailleurs, interdit.
      PNG_TRANSPARENCY = { 0 => 2, 2 => 6 }.freeze
      WEBP_KEPT = [ "VP8 ", "VP8L", "VP8X", "ALPH" ].freeze
      WEBP_IMAGES = [ "VP8 ", "VP8L" ].freeze
      # Seul le drapeau de transparence (0x10) de l'en-tête étendu VP8X reste : ni ICC, ni Exif, ni XMP, ni animation ;
      # ses trois octets réservés sont remis à zéro.
      WEBP_ALPHA_FLAG = 0x10
      WEBP_EXTENDED_LENGTH = [ 10 ].pack("V").freeze
      # En-tête ALPH : bits réservés (7-6), pré-traitement 2 ou 3 (bit 5) et compression 2 ou 3 (bit 1) interdits.
      WEBP_ALPHA_FORBIDDEN = 0xE2

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

      # Les seules parties de la liste blanche, dans leur forme standard. Un fichier que read refuse est rendu tel quel :
      # il n'est jamais stocké, et ses parties mal formées ne sont jamais réécrites.
      def strip(bytes)
        bytes = bytes.to_s.b
        return bytes if read(bytes).nil?

        parts = parts_of(bytes)
        stripped = [ bytes.byteslice(0, parts.first.at), *parts.filter_map { kept(bytes, it) } ].join.b
        format_of(bytes) == :webp ? fix_webp(stripped) : stripped
      end

      def format_of(bytes)
        if bytes.start_with?(JPEG_SIGNATURE) then :jpeg
        elsif bytes.start_with?(PNG_SIGNATURE) then :png
        elsif bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WEBP" then :webp
        end
      end

      # Appelé sur une image que read a lue : son format est connu.
      def parts_of(bytes)
        case format_of(bytes)
        when :jpeg then jpeg_parts(bytes)
        when :png then png_parts(bytes)
        else webp_parts(bytes)
        end
      end

      # Ce qui reste d'une partie après le filtre : ses octets, sa forme standard, ou nil.
      def kept(bytes, part)
        raw = bytes.byteslice(part.at, part.size)
        case format_of(bytes)
        when :jpeg then jpeg_kept(bytes, part)
        when :png then raw if PNG_KEPT.include?(part.type)
        else webp_kept(raw, part)
        end
      end

      def webp_kept(raw, part)
        case part.type
        when "VP8X" then raw.byteslice(0, 8) + [ raw.getbyte(8) & WEBP_ALPHA_FLAG, 0, 0, 0 ].pack("C4") + raw.byteslice(12, 6)
        when *WEBP_KEPT then raw
        end
      end

      # Sans les octets de remplissage : le segment commence à son marqueur. Ce qui suit EOI n'est pas dans la liste.
      def jpeg_kept(bytes, part)
        segment = bytes.byteslice(part.data - 2, part.at + part.size - part.data + 2)
        case part.type
        when JPEG_JFIF then JFIF_SEGMENT if segment.byteslice(4, 5) == "JFIF\0"
        when JPEG_ADOBE then ADOBE_PREFIX + segment.byteslice(15, 1) if segment.byteslice(4, 5) == "Adobe" && segment.bytesize == 16
        else segment if JPEG_KEPT.include?(part.type)
        end
      end

      # Une partie retirée ou réécrite signale des métadonnées.
      def metadata?(bytes, part) = kept(bytes, part) != bytes.byteslice(part.at, part.size)

      # Un seul SOF, avant le premier scan, donne la taille.
      def jpeg(bytes)
        parts = jpeg_parts(bytes)
        return if parts.nil?

        frames = parts.each_index.select { JPEG_FRAMES.include?(parts[it].type) }
        frame = frames.first
        scan = parts.index { it.type == JPEG_SCAN }
        return unless frames.one? && scan && frame < scan

        height, width = fields(bytes, parts[frame].data + 3, "nn", 4)
        facts(bytes, :jpeg, [ width, height ], parts)
      end

      def png(bytes)
        parts = png_parts(bytes)
        facts(bytes, :png, fields(bytes, parts.first.data, "NN", 8), parts) if parts
      end

      # Une seule image (VP8 ou VP8L) : une animation n'est pas une photo. Elle donne la taille ; l'en-tête étendu, s'il
      # existe, vient en premier, une seule fois, et annonce la même taille.
      def webp(bytes)
        parts = webp_parts(bytes)
        return if parts.nil?

        images = parts.select { WEBP_IMAGES.include?(it.type) }
        return unless images.one? && webp_layout?(parts.map(&:type), images.first.type)

        size = webp_size(bytes, images.first)
        facts(bytes, :webp, size, parts) if size && webp_extension?(bytes, parts, size)
      end

      # VP8X seulement en premier ; ALPH au plus une fois, dans un fichier étendu, avant une image avec perte.
      def webp_layout?(types, image)
        alpha = types.index("ALPH")
        types.count("VP8X") == (types.first == "VP8X" ? 1 : 0) && types.count("ALPH") <= 1 &&
          (alpha.nil? || (types.first == "VP8X" && alpha < types.index(image) && image == "VP8 "))
      end

      # VP8X de 10 octets exactement, dont la taille est celle du bitstream ; ALPH bien formé.
      def webp_extension?(bytes, parts, size)
        extended = parts.first if parts.first.type == "VP8X"
        alpha = parts.find { it.type == "ALPH" }
        (extended.nil? || (bytes.byteslice(extended.at + 4, 4) == WEBP_EXTENDED_LENGTH && webp_size(bytes, extended) == size)) &&
          (alpha.nil? || webp_alpha?(bytes, alpha, size))
      end

      # Compression 0 : un octet par pixel, rien de plus ; compression 1 : un flux VP8L sans en-tête, non vérifiable sans
      # décodage (limite documentée dans l'ADR-0060).
      def webp_alpha?(bytes, part, size)
        length = bytes.unpack1("V", offset: part.at + 4)
        header = bytes.getbyte(part.data)
        length.positive? && header.nobits?(WEBP_ALPHA_FORBIDDEN) && (header.anybits?(1) || length == 1 + size.inject(:*))
      end

      # Taille lue dans l'en-tête étendu (VP8X, déjà vérifié de 10 octets), sans perte (VP8L, version 0) ou avec perte
      # (VP8 ), toujours dans le chunk lui-même.
      def webp_size(bytes, part)
        payload = bytes.byteslice(part.data, part.size - 8)
        case part.type
        when "VP8X"
          width_low, width_high, height_low, height_high = fields(payload, 4, "vCvC", 6)
          [ width_low + (width_high << 16) + 1, height_low + (height_high << 16) + 1 ]
        when "VP8L"
          signature, bits = fields(payload, 0, "CV", 5)
          [ (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1 ] if signature == 0x2F && (bits >> 29).zero?
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
        return unless size.all?(&:positive?)

        Facts.new(format:, width:, height:, metadata: parts.any? { metadata?(bytes, it) })
      end

      # Tout le fichier, segment par segment, scans compris, jusqu'au premier EOI. Octets de remplissage 0xFF acceptés
      # avant un marqueur (T.81 § B.1.1.2) ; tout autre octet hors segment, ou un segment gardé plus long que ses champs,
      # rend le fichier illisible. Ce qui suit EOI (images secondaires d'un téléphone) forme une dernière partie, retirée.
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
          return if stop.nil? || !jpeg_exact?(bytes, marker, marker_at + 2)

          parts << Part.new(type: marker, at:, size: stop - at, data: marker_at + 2)
          return parts + jpeg_trailer(bytes, stop) if marker == JPEG_END

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

      def jpeg_trailer(bytes, stop)
        stop == bytes.bytesize ? [] : [ Part.new(type: JPEG_TRAILER, at: stop, size: bytes.bytesize - stop, data: stop) ]
      end

      # Longueur exacte des segments gardés (T.81 § B.2) : aucun octet libre derrière leurs champs. SOF : 3 octets par
      # composante ; SOS : 2 ; DRI et DNL : une valeur ; DAC : 2 octets par table ; DQT et DHT : tables successives.
      def jpeg_exact?(bytes, marker, data)
        return true if marker == JPEG_END

        payload = bytes.byteslice(data + 2, bytes.unpack1("n", offset: data) - 2)
        case marker
        when *JPEG_FRAMES then payload.bytesize == 6 + (3 * payload.getbyte(5).to_i)
        when JPEG_SCAN then payload.bytesize == 4 + (2 * payload.getbyte(0).to_i)
        when 0xDD, 0xDC then payload.bytesize == 2
        when JPEG_DAC then payload.bytesize.positive? && payload.bytesize.even?
        when JPEG_DQT then jpeg_tables?(payload) { |precision, _| 1 + (64 * (precision + 1)) }
        when JPEG_DHT then jpeg_tables?(payload) { |_, counts| 17 + counts.sum if counts.size == 16 }
        else true
        end
      end

      # Chaque table : classe ou précision 0 ou 1, numéro 0 à 3, puis la longueur que rend le bloc ; la dernière finit
      # exactement le segment.
      def jpeg_tables?(payload)
        at = 0
        while at < payload.bytesize
          spec = payload.getbyte(at)
          size = yield(spec >> 4, payload.byteslice(at + 1, 16).bytes) if spec >> 4 <= 1 && (spec & 0x0F) <= 3
          return false if size.nil?

          at += size
        end
        at.positive? && at == payload.bytesize
      end

      # Chunks PNG (longueur, type, données, CRC) : IHDR d'abord, IDAT au moins, IEND à la toute fin, une seule fois.
      def png_parts(bytes)
        parts = chunks(bytes, 8) do |at|
          length, type = fields(bytes, at, "Na4", 8)
          next unless length && type.match?(/\A[A-Za-z]{4}\z/) && at + 12 + length <= bytes.bytesize
          next unless fields(bytes, at + 8 + length, "N", 4).first == Zlib.crc32(bytes.byteslice(at + 4, 4 + length))

          Part.new(type:, at:, size: 12 + length, data: at + 8)
        end
        parts if parts&.first&.type == "IHDR" && parts.first.size == 25 && parts.last.type == "IEND" &&
                 parts.any? { it.type == "IDAT" } && png_exact?(bytes, parts)
      end

      # IHDR selon la norme (profondeur permise, compression et filtre 0, entrelacement 0 ou 1) ; chunks uniques ; chaque
      # chunk gardé à sa longueur exacte.
      def png_exact?(bytes, parts)
        depth, color, compression, filter, interlace = bytes.byteslice(parts.first.data + 8, 5).unpack("C5")
        types = parts.map(&:type)
        palette = parts.find { it.type == "PLTE" }
        entries = palette ? (palette.size - 12) / 3 : 0
        PNG_DEPTHS.fetch(color, []).include?(depth) && (compression | filter).zero? && interlace <= 1 &&
          PNG_ONCE.all? { types.count(it) <= 1 } && png_palette?(palette, color) &&
          parts.all? { png_chunk?(bytes, it, color, depth, entries) }
      end

      # Palette exigée en mode indexé, interdite en gris, permise en couleurs.
      def png_palette?(palette, color)
        case color
        when PNG_PALETTE then !palette.nil?
        when 0, 4 then palette.nil?
        else true
        end
      end

      # PLTE : des triplets, pas plus que la profondeur n'en adresse ; tRNS : selon le type ; sRGB : une intention de 0 à
      # 3 ; IEND, gAMA, cHRM : leur longueur fixe. IHDR (25 octets) et IDAT sont vérifiés par ailleurs.
      def png_chunk?(bytes, part, color, depth, entries)
        data = bytes.byteslice(part.data, part.size - 12)
        case part.type
        when "PLTE" then (data.bytesize % 3).zero? && entries.between?(1, color == PNG_PALETTE ? 2**depth : 256)
        when "tRNS" then png_transparency?(data, color, depth, entries)
        when "sRGB" then data.bytesize == 1 && data.getbyte(0) <= 3
        else PNG_LENGTHS.fetch(part.type, data.bytesize) == data.bytesize
        end
      end

      # Indexé : une opacité par entrée de la palette au plus ; gris ou couleurs : des échantillons dans la profondeur.
      def png_transparency?(data, color, depth, entries)
        return data.bytesize.between?(1, entries) if color == PNG_PALETTE

        data.bytesize == PNG_TRANSPARENCY[color] && data.unpack("n*").all? { it < 2**depth }
      end

      # Chunks RIFF (type, longueur, données, octet de bourrage nul après une longueur impaire), exactement dans la
      # longueur annoncée.
      def webp_parts(bytes)
        return unless fields(bytes, 4, "V", 4).first == bytes.bytesize - 8

        chunks(bytes, 12) do |at|
          type, length = fields(bytes, at, "a4V", 8)
          next if length.nil?

          size = 8 + length + (length % 2)
          next if at + size > bytes.bytesize || (length.odd? && bytes.getbyte(at + size - 1) != 0)

          Part.new(type:, at:, size:, data: at + 8)
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

      # Le conteneur RIFF annonce sa longueur : elle est recalculée (VP8X, lui, est réécrit par webp_kept).
      def fix_webp(body)
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
