# 🧠 DOMAINE · Entities::Shared::ImageHeader
# Rôle : lit une image JPEG, PNG ou WebP entière sans bibliothèque (format réel, dimensions, métadonnées) et retire ses métadonnées
# ADR  : 0060
module Entities
  module Shared
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
      # DNL (0xDC) aussi : il ne sert qu'à une hauteur nulle dans le SOF, qui est refusée ; accepté, il porterait deux
      # octets libres.
      JPEG_UNEXPECTED = [ 0x00, 0x01, *(0xD0..0xD8), 0xDC ].freeze
      # Premier octet qui n'est pas un remplissage ; dans un scan, le prochain marqueur (0xFF suivi d'autre chose que 0x00,
      # bourrage, ou RSTn, remise à zéro). Cherchés par une expression, sans boucle octet par octet.
      JPEG_NOT_FILL = /[^\xFF]/n
      JPEG_MARKER = /\xFF[^\x00\xD0-\xD7]/n
      # Plafonds : une photo compte une vingtaine de segments et une dizaine de scans ; un fichier fait de centaines de
      # milliers de parties vides est refusé avant d'être lu en entier.
      JPEG_MAX_SEGMENTS = 256
      JPEG_MAX_SCANS = 64
      # Ce qui suit le premier EOI (Motion Photo, image MPF, carte de gain d'un téléphone) : lu comme une partie retirée.
      JPEG_TRAILER = :trailer
      JPEG_DQT = 0xDB
      JPEG_DHT = 0xC4
      JPEG_DAC = 0xCC
      JPEG_DRI = 0xDD
      # Codage arithmétique : SOF9 à SOF15 (les seuls où une table DAC sert).
      JPEG_ARITHMETIC = [ 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF ].freeze
      JPEG_PROGRESSIVE = [ 0xC2, 0xC6, 0xCA, 0xCE ].freeze
      # Sans perte (SOF3, 7, 11, 15) : aucun appareil photo n'en écrit ; refusé.
      JPEG_LOSSLESS = [ 0xC3, 0xC7, 0xCB, 0xCF ].freeze
      # Table de Huffman (T.81 Annexe K, précision de 8 bits) : 256 codes au plus ; DC : catégories 0 à 11 ; AC : EOB
      # (0x00), ZRL (0xF0) ou une paire course/taille de taille 1 à 10 ; en progressif, aussi EOBn (taille 0, course 1 à
      # 14, § G.1.2.2).
      JPEG_MAX_CODES = 256
      JPEG_DC_SYMBOLS = (0..11)
      JPEG_AC_SIZES = (1..10)
      JPEG_DEFINITIONS = [ JPEG_DQT, JPEG_DHT, JPEG_DAC, JPEG_DRI ].freeze
      # Liste blanche : seuls les segments et chunks qui dessinent l'image restent, réécrits dans leur forme standard
      # quand ils ont des champs libres. Tout le reste part, quels que soient son nom ou sa signature — un profil ICC
      # (APP2, iCCP, ICCP) aussi : son contenu est libre, il a transporté un secret dans la contre-épreuve de la PR #50.
      # JPEG : SOFn (sauf sans perte), DHT, DAC, DQT, DRI, SOS (avec son scan), EOI ; JFIF (APP0) et Adobe (APP14)
      # réécrits. (DNL est refusé, voir JPEG_UNEXPECTED.)
      JPEG_KEPT = [ *JPEG_FRAMES, JPEG_DHT, JPEG_DAC, JPEG_DQT, JPEG_DRI, JPEG_SCAN, JPEG_END ].freeze
      JPEG_JFIF = 0xE0
      JPEG_ADOBE = 0xEE
      # JFIF 1.01, sans unité, rapport 1:1, sans vignette ; Adobe version 100, drapeaux nuls, puis la transformée d'origine.
      JFIF_SEGMENT = "\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00".b.freeze
      ADOBE_PREFIX = "\xFF\xEE\x00\x0EAdobe\x00\x64\x00\x00\x00\x00".b.freeze
      # cHRM part (ses 32 octets sont libres et inutiles sans profil) ; PLTE seulement en mode indexé (en couleurs, c'est
      # une palette suggérée, inutile au rendu) ; gAMA seulement dans une plage plausible (gamma de 0,01 à 10).
      PNG_KEPT = %w[IHDR PLTE IDAT IEND tRNS gAMA sRGB].freeze
      PNG_GAMMA = (1_000..1_000_000)
      # Avant le premier IDAT (PNG § 5.6) ; IDAT consécutifs.
      PNG_BEFORE_IMAGE = %w[PLTE tRNS gAMA cHRM sRGB].freeze
      PNG_MAX_CHUNKS = 4096
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
      WEBP_MAX_CHUNKS = 64

      module_function

      # bytes : String → Facts | nil (ni JPEG, ni PNG, ni WebP, ou flux incomplet ou mal formé)
      def read(bytes) = analyze(bytes.to_s.b)&.first

      # Les seules parties de la liste blanche, dans leur forme standard. Un fichier que read refuse est rendu tel quel :
      # il n'est jamais stocké, et ses parties mal formées ne sont jamais réécrites. Le fichier n'est lu qu'une fois.
      def strip(bytes)
        bytes = bytes.to_s.b
        _facts, parts = analyze(bytes)
        return bytes if parts.nil?

        stripped = [ bytes.byteslice(0, parts.first.at), *parts.filter_map { kept(bytes, it) } ].join.b
        format_of(bytes) == :webp ? fix_webp(stripped) : stripped
      end

      def format_of(bytes)
        if bytes.start_with?(JPEG_SIGNATURE) then :jpeg
        elsif bytes.start_with?(PNG_SIGNATURE) then :png
        elsif bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WEBP" then :webp
        end
      end

      # [Facts, parties] | nil : une seule lecture sert à read et à strip.
      def analyze(bytes)
        case format_of(bytes)
        when :jpeg then jpeg(bytes)
        when :png then png(bytes)
        when :webp then webp(bytes)
        end
      end

      # Ce qui reste d'une partie après le filtre : ses octets, sa forme standard, ou nil.
      def kept(bytes, part)
        raw = bytes.byteslice(part.at, part.size)
        case format_of(bytes)
        when :jpeg then jpeg_kept(bytes, part)
        when :png then raw if png_kept?(bytes, part)
        else webp_kept(raw, part)
        end
      end

      # Le type de couleur est l'octet 25 du fichier (IHDR vient en premier, déjà vérifié).
      def png_kept?(bytes, part)
        case part.type
        when "PLTE" then bytes.getbyte(25) == PNG_PALETTE
        when "gAMA" then PNG_GAMMA.cover?(bytes.unpack1("N", offset: part.data))
        else PNG_KEPT.include?(part.type)
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
        return unless frames.one? && scan && frame < scan && !JPEG_LOSSLESS.include?(parts[frame].type) && jpeg_adobe?(bytes, parts) && jpeg_frame?(bytes, parts, parts[frame])

        height, width = fields(bytes, parts[frame].data + 3, "nn", 4)
        result(bytes, :jpeg, [ width, height ], parts)
      end

      # Un seul segment Adobe ; gardé (longueur standard), sa transformée vaut 0 (aucune), 1 (YCbCr) ou 2 (YCCK).
      def jpeg_adobe?(bytes, parts)
        adobe = parts.select { it.type == JPEG_ADOBE && bytes.byteslice(it.data + 2, 5) == "Adobe" }
        adobe.size <= 1 && adobe.all? { bytes.unpack1("n", offset: it.data) != 14 || bytes.getbyte(it.data + 13) <= 2 }
      end

      # Chaque table définie (DQT, DHT, DAC) et chaque intervalle DRI sert avant d'être redéfini : DQT aux composantes du
      # SOF, DHT (codage de Huffman) ou DAC (codage arithmétique) et DRI au scan qui suit. Une table jamais utilisée, ou
      # redéfinie sans avoir servi, ne transporterait que des octets libres. Un JPEG progressif redéfinit ses tables DHT
      # entre deux scans : chaque définition sert au scan suivant, elle est gardée.
      # Précision 8 bits seulement : un JPEG 12 ou 16 bits n'est affiché par aucun navigateur.
      def jpeg_frame?(bytes, parts, frame)
        return false unless bytes.getbyte(frame.data + 2) == 8

        components = (0...bytes.getbyte(frame.data + 7)).to_h { bytes.byteslice(frame.data + 8 + (3 * it), 3).unpack("CxC") }
        jpeg_sequential?(bytes, parts, frame, components) && jpeg_coherent?(bytes, parts, frame, components)
      end

      # Un JPEG séquentiel (non progressif) code chaque composante dans exactement un scan : un scan de plus ne
      # transporterait que des données entropiques libres.
      def jpeg_sequential?(bytes, parts, frame, components)
        return true if JPEG_PROGRESSIVE.include?(frame.type)

        coded = parts.select { it.type == JPEG_SCAN }.flat_map do |scan|
          bytes.byteslice(scan.data + 3, 2 * bytes.getbyte(scan.data + 2)).bytes.each_slice(2).map(&:first)
        end
        coded.sort == components.keys.sort
      end

      def jpeg_coherent?(bytes, parts, frame, components)
        coding = JPEG_ARITHMETIC.include?(frame.type) ? :arithmetic : :huffman
        progressive = JPEG_PROGRESSIVE.include?(frame.type)
        pending = {}
        parts.each do |part|
          defined = jpeg_definitions(bytes, part, progressive)
          used = jpeg_uses(bytes, part, components, coding)
          return false if defined.nil? || used.nil?

          defined.each do |key|
            return false if pending.key?(key)

            pending[key] = true
          end
          used.each { pending.delete(it) }
        end
        pending.empty?
      end

      def jpeg_definitions(bytes, part, progressive)
        return [] unless JPEG_DEFINITIONS.include?(part.type)

        payload = jpeg_payload(bytes, part)
        case part.type
        when JPEG_DQT then jpeg_table_specs(part.type, payload).map { [ :quantization, it & 0x0F ] }
        when JPEG_DHT then jpeg_table_specs(part.type, payload, progressive:)&.map { [ :huffman, it >> 4, it & 0x0F ] }
        when JPEG_DAC then jpeg_conditioning(payload)
        else [ [ :restart ] ]
        end
      end

      # DAC : des paires (classe et numéro, valeur) ; classe 0 (DC) : bornes L ≤ U ; classe 1 (AC) : Kx de 1 à 63.
      def jpeg_conditioning(payload)
        payload.bytes.each_slice(2).map do |spec, value|
          klass, table = spec >> 4, spec & 0x0F
          return unless klass <= 1 && table <= 3 && (klass == 1 ? value.between?(1, 63) : (value & 0x0F) <= (value >> 4))

          [ :arithmetic, klass, table ]
        end
      end

      def jpeg_uses(bytes, part, components, coding)
        case part.type
        when *JPEG_FRAMES then components.values.map { [ :quantization, it ] }
        when JPEG_SCAN then jpeg_scan_tables(bytes, part, components, coding)
        else []
        end
      end

      # Composantes du scan : 1 à 4, toutes déclarées par le SOF. Table DC servie par un premier passage DC (Ss = 0,
      # Ah = 0), table AC dès que Se > 0 ; un JPEG sans perte (SOF3), qu'aucun appareil photo n'écrit, est donc refusé.
      def jpeg_scan_tables(bytes, part, components, coding)
        count = bytes.getbyte(part.data + 2)
        selectors = bytes.byteslice(part.data + 3, 2 * count).bytes.each_slice(2)
        start, stop, approximation = bytes.byteslice(part.data + 3 + (2 * count), 3).bytes
        return unless count.between?(1, 4) && selectors.all? { components.key?(it.first) }

        selectors.flat_map do |_, spec|
          [ ([ coding, 0, spec >> 4 ] if start.zero? && (approximation >> 4).zero?), ([ coding, 1, spec & 0x0F ] if stop.positive?) ]
        end.compact + [ [ :restart ] ]
      end

      def jpeg_payload(bytes, part) = bytes.byteslice(part.data + 2, bytes.unpack1("n", offset: part.data) - 2)

      def png(bytes)
        parts = png_parts(bytes)
        result(bytes, :png, fields(bytes, parts.first.data, "NN", 8), parts) if parts
      end

      # Une seule image (VP8 ou VP8L) : une animation n'est pas une photo. Elle donne la taille ; l'en-tête étendu, s'il
      # existe, vient en premier, une seule fois, et annonce la même taille.
      def webp(bytes)
        parts = webp_parts(bytes)
        return if parts.nil?

        images = parts.select { WEBP_IMAGES.include?(it.type) }
        return unless images.one? && webp_layout?(parts.map(&:type), images.first.type)

        size = webp_size(bytes, images.first)
        result(bytes, :webp, size, parts) if size && webp_extension?(bytes, parts, size)
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

      def result(bytes, format, size, parts)
        width, height = size
        return unless size.all?(&:positive?)

        [ Facts.new(format:, width:, height:, metadata: parts.any? { metadata?(bytes, it) }), parts ]
      end

      # Tout le fichier, segment par segment, scans compris, jusqu'au premier EOI. Octets de remplissage 0xFF acceptés
      # avant un marqueur (T.81 § B.1.1.2) ; tout autre octet hors segment, ou un segment gardé plus long que ses champs,
      # rend le fichier illisible. Ce qui suit EOI (images secondaires d'un téléphone) forme une dernière partie, retirée.
      def jpeg_parts(bytes)
        parts = []
        counts = [ 0, 0 ]
        at = 2
        loop do
          return unless bytes.getbyte(at) == 0xFF

          marker_at = (bytes.index(JPEG_NOT_FILL, at + 1) || bytes.bytesize) - 1
          marker = bytes.getbyte(marker_at + 1)
          return if marker.nil? || JPEG_UNEXPECTED.include?(marker)

          stop = jpeg_segment_end(bytes, marker, marker_at + 2)
          return if stop.nil? || !jpeg_exact?(bytes, marker, marker_at + 2)

          parts << Part.new(type: marker, at:, size: stop - at, data: marker_at + 2)
          counts[marker == JPEG_SCAN ? 1 : 0] += 1
          return if counts.first > JPEG_MAX_SEGMENTS || counts.last > JPEG_MAX_SCANS
          return parts + jpeg_trailer(bytes, stop) if marker == JPEG_END

          at = stop
        end
      end

      # Fin du segment : EOI n'a pas de longueur ; un scan continue par ses données entropiques jusqu'au prochain
      # marqueur (0xFF suivi d'autre chose que 0x00, bourrage, ou RSTn, remise à zéro) ; sans marqueur, illisible.
      def jpeg_segment_end(bytes, marker, data)
        return data if marker == JPEG_END

        length = fields(bytes, data, "n", 2)&.first
        return unless length && length >= 2 && data + length <= bytes.bytesize
        return data + length unless marker == JPEG_SCAN

        bytes.index(JPEG_MARKER, data + length)
      end

      def jpeg_trailer(bytes, stop)
        stop == bytes.bytesize ? [] : [ Part.new(type: JPEG_TRAILER, at: stop, size: bytes.bytesize - stop, data: stop) ]
      end

      # Longueur exacte des segments gardés (T.81 § B.2) : aucun octet libre derrière leurs champs. SOF : 3 octets par
      # composante ; SOS : 2 ; DRI : une valeur ; DAC : 2 octets par table ; DQT et DHT : tables successives.
      def jpeg_exact?(bytes, marker, data)
        return true if marker == JPEG_END

        payload = bytes.byteslice(data + 2, bytes.unpack1("n", offset: data) - 2)
        case marker
        when *JPEG_FRAMES then payload.bytesize == 6 + (3 * payload.getbyte(5).to_i)
        when JPEG_SCAN then payload.bytesize == 4 + (2 * payload.getbyte(0).to_i)
        when JPEG_DRI then payload.bytesize == 2
        when JPEG_DAC then payload.bytesize.positive? && payload.bytesize.even?
        when JPEG_DQT, JPEG_DHT then !jpeg_table_specs(marker, payload).nil?
        else true
        end
      end

      # DQT : précision, puis 64 valeurs d'un ou deux octets ; DHT : 16 effectifs, puis autant de codes.
      # progressive : à la lecture des segments, le SOF n'est pas encore connu, les EOBn sont admis ; jpeg_coherent?
      # revérifie chaque table avec le vrai type de trame.
      def jpeg_table_specs(marker, payload, progressive: true)
        if marker == JPEG_DQT then jpeg_tables(payload) { |precision, _| 1 + (64 * (precision + 1)) }
        else jpeg_tables(payload) { |klass, at| jpeg_huffman_size(payload, klass, at, progressive) }
        end
      end

      # Une table de Huffman réalisable : 1 à 256 codes ; à chaque longueur, le code canonique suivant tient dans cette
      # longueur sans être le code tout à 1 (T.81 § C, comme libjpeg) ; symboles distincts, valides pour la classe.
      def jpeg_huffman_size(payload, klass, at, progressive)
        counts = payload.byteslice(at, 16).bytes
        total = counts.sum
        symbols = payload.byteslice(at + 16, total).to_s.bytes
        return unless counts.size == 16 && total.between?(1, JPEG_MAX_CODES) && symbols.uniq.size == total
        return unless jpeg_prefix_code?(counts) && symbols.all? { jpeg_symbol?(klass, it, progressive) }

        17 + total
      end

      def jpeg_prefix_code?(counts)
        code = 0
        counts.each.with_index(1).all? do |count, length|
          code += count
          (code < (1 << length)).tap { code <<= 1 }
        end
      end

      def jpeg_symbol?(klass, symbol, progressive)
        if klass.zero? then JPEG_DC_SYMBOLS.cover?(symbol)
        elsif (symbol & 0x0F).zero? then [ 0x00, 0xF0 ].include?(symbol) || progressive
        else JPEG_AC_SIZES.cover?(symbol & 0x0F)
        end
      end

      # Chaque table : classe ou précision 0 ou 1, numéro 0 à 3, puis la longueur que rend le bloc ; la dernière finit
      # exactement le segment. Rend l'octet d'en-tête de chaque table, ou nil.
      def jpeg_tables(payload)
        at = 0
        specs = []
        while at < payload.bytesize
          spec = payload.getbyte(at)
          size = yield(spec >> 4, at + 1) if spec >> 4 <= 1 && (spec & 0x0F) <= 3
          return if size.nil?

          specs << spec
          at += size
        end
        specs if specs.any? && at == payload.bytesize
      end

      # Chunks PNG (longueur, type, données, CRC) : IHDR d'abord, IDAT au moins, IEND à la toute fin, une seule fois.
      def png_parts(bytes)
        parts = chunks(bytes, 8, PNG_MAX_CHUNKS) do |at|
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
          PNG_ONCE.all? { types.count(it) <= 1 } && png_palette?(palette, color) && png_ordered?(types) &&
          parts.all? { png_chunk?(bytes, it, color, depth, entries) }
      end

      # IDAT consécutifs ; PLTE, tRNS, gAMA, cHRM, sRGB avant eux ; tRNS après PLTE. (IHDR premier et IEND dernier, unique,
      # sont vérifiés par png_parts.)
      def png_ordered?(types)
        first = types.index("IDAT")
        last = types.rindex("IDAT")
        transparency = types.index("tRNS")
        palette = types.index("PLTE")
        types[first..last].all?("IDAT") && PNG_BEFORE_IMAGE.all? { types.index(it).to_i < first } &&
          (transparency.nil? || palette.nil? || transparency > palette)
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

        chunks(bytes, 12, WEBP_MAX_CHUNKS) do |at|
          type, length = fields(bytes, at, "a4V", 8)
          next if length.nil?

          size = 8 + length + (length % 2)
          next if at + size > bytes.bytesize || (length.odd? && bytes.getbyte(at + size - 1) != 0)

          Part.new(type:, at:, size:, data: at + 8)
        end
      end

      # Parties successives du bloc jusqu'à la fin exacte du fichier ; nil dès qu'une partie est illisible.
      def chunks(bytes, at, limit)
        parts = []
        while at < bytes.bytesize
          part = yield(at)
          return if part.nil? || parts.size >= limit

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
