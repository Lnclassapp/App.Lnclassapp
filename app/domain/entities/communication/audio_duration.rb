# 🧠 DOMAINE · Entities::Communication::AudioDuration
# Rôle : mesure la durée d'un audio MP3 ou M4A dans ses octets (trame par trame, boîte par boîte), sans bibliothèque
# ADR  : 0118 (§4.2, menace §4.4), 0045, 0078 · UDR : 0071 (§3.8)
module Entities
  module Communication
    # Un fichier téléversé est une entrée hostile : on ne croit aucune durée déclarée (Xing, VBRI, mvhd seul), on mesure ce
    # qu'il contient. Tout doute rend nil (« illisible »), jamais une durée courte. Parcours linéaire, borné par le poids du
    # fichier (1 Mo, vérifié avant toute lecture) : chaque trame mesure au moins 24 octets, chaque boîte au moins 8.
    module AudioDuration
      # bytes : String, le fichier entier ; format : :mpeg ou :mp4 (AudioHeader.format_of) → Float (secondes) ou nil.
      # Fonction pure : les octets reçus ne sont pas modifiés.
      def self.seconds_of(bytes, format:)
        bytes = bytes.to_s.b
        catch(:unreadable) do
          case format
          when :mpeg then Mpeg.seconds(bytes)
          when :mp4 then Mp4.seconds(bytes)
          end
        end
      end

      # MPEG audio, couches I à III, versions 1, 2 et 2,5.
      module Mpeg
        NOT_NULL = /[^\x00]/n
        SYNC = 0x7FF
        RESERVED_VERSION = 0b01
        RESERVED_RATE = 0b11
        FRAME_HEADER_BYTES = 4
        ID3V2_HEADER_BYTES = 10
        ID3V2_FOOTER_FLAG = 0x10
        # Fins admises après la dernière trame : des octets nuls, un ID3v1 (128 octets) et/ou une étiquette APEv2 qui va
        # jusqu'à la fin du fichier (ou jusqu'à l'ID3v1). Tout autre octet est illisible.
        ID3V1_BYTES = 128
        APE_MARK = "APETAGEX".b
        APE_PART_BYTES = 32
        APE_SIZE_OFFSET = 12
        APE_FLAGS_OFFSET = 20
        APE_HEADER_FLAG = 31
        # [famille de version (1 : MPEG-1, 2 : MPEG-2 et 2,5), couche] → débits en kbit/s, indexés par les 4 bits de l'en-tête
        # (l'index 0, « libre », et 15, réservé, sont refusés avant la lecture).
        BITRATES = {
          [ 1, 1 ] => [ nil, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448 ],
          [ 1, 2 ] => [ nil, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384 ],
          [ 1, 3 ] => [ nil, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 ],
          [ 2, 1 ] => [ nil, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256 ],
          [ 2, 2 ] => [ nil, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 ],
          [ 2, 3 ] => [ nil, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 ]
        }.freeze
        # Bits de version (3 : MPEG-1, 2 : MPEG-2, 0 : MPEG-2,5) → fréquences en Hz.
        SAMPLE_RATES = { 3 => [ 44_100, 48_000, 32_000 ], 2 => [ 22_050, 24_000, 16_000 ], 0 => [ 11_025, 12_000, 8000 ] }.freeze

        Frame = Data.define(:length, :seconds)

        def self.seconds(bytes)
          pos = bytes.index(NOT_NULL, after_id3v2(bytes))
          return if pos.nil?

          total = 0.0
          frames = 0
          while pos < bytes.bytesize
            frame = frame_at(bytes, pos)
            return (total if frames.positive? && clean_end?(bytes, pos)) if frame.nil?

            total += frame.seconds
            frames += 1
            pos += frame.length
          end
          total
        end

        # Après l'étiquette ID3v2 : taille en 4 octets « syncsafe » (7 bits chacun), + 10 si elle a un pied.
        def self.after_id3v2(bytes)
          return 0 unless bytes.start_with?("ID3".b)

          header = bytes.byteslice(0, ID3V2_HEADER_BYTES)
          throw :unreadable if header.bytesize < ID3V2_HEADER_BYTES || header.byteslice(6, 4).bytes.any? { it >= 0x80 }

          size = header.byteslice(6, 4).bytes.inject(0) { |sum, byte| (sum << 7) | byte }
          footer = header.getbyte(5).anybits?(ID3V2_FOOTER_FLAG) ? ID3V2_HEADER_BYTES : 0
          ID3V2_HEADER_BYTES + size + footer
        end

        # La trame qui commence à pos, ou nil si ce n'est pas une trame valide. Une trame tronquée par la fin du fichier compte.
        def self.frame_at(bytes, pos)
          return if pos + FRAME_HEADER_BYTES > bytes.bytesize

          word = bytes.unpack1("N", offset: pos)
          version = (word >> 19) & 0b11
          layer = 4 - ((word >> 17) & 0b11)
          bitrate = (word >> 12) & 0b1111
          rate = (word >> 10) & 0b11
          return unless (word >> 21) == SYNC && version != RESERVED_VERSION && layer != 4 && rate != RESERVED_RATE &&
                        bitrate.between?(1, 14)

          measure(version, layer, bitrate, rate, (word >> 9) & 1)
        end

        def self.measure(version, layer, bitrate, rate, padding)
          family = version == 3 ? 1 : 2
          hertz = SAMPLE_RATES.fetch(version)[rate]
          bits = BITRATES.fetch([ family, layer ])[bitrate] * 1000
          samples = layer == 1 ? 384 : (layer == 3 && family == 2 ? 576 : 1152)
          length = layer == 1 ? ((12 * bits / hertz) + padding) * 4 : ((samples / 8) * bits / hertz) + padding
          Frame.new(length:, seconds: samples.fdiv(hertz))
        end

        # Ce qui suit la dernière trame : des octets nuls jusqu'au bout, ou [APEv2] puis [ID3v1], rien d'autre.
        def self.clean_end?(bytes, pos)
          rest = bytes.byteslice(pos..)
          return true unless rest.match?(NOT_NULL)

          rest = rest.byteslice(0, rest.bytesize - ID3V1_BYTES) if id3v1?(rest)
          rest.empty? || ape_to_end?(rest)
        end

        def self.id3v1?(rest)
          rest.bytesize >= ID3V1_BYTES && rest.byteslice(-ID3V1_BYTES, 3) == "TAG".b
        end

        # rest est exactement une étiquette APEv2 : avec en-tête (il ouvre rest) ou sans (le pied la ferme). La taille
        # (petit-boutiste, octets 12..15) inclut le pied mais pas l'en-tête optionnel de 32 octets.
        def self.ape_to_end?(rest)
          return false if rest.bytesize < APE_PART_BYTES

          if rest.start_with?(APE_MARK)
            size = rest.unpack1("V", offset: APE_SIZE_OFFSET)
            size >= APE_PART_BYTES && rest.bytesize == APE_PART_BYTES + size
          else
            footer = rest.byteslice(-APE_PART_BYTES, APE_PART_BYTES)
            footer.start_with?(APE_MARK) && !footer.unpack1("V", offset: APE_FLAGS_OFFSET).anybits?(1 << APE_HEADER_FLAG) &&
              footer.unpack1("V", offset: APE_SIZE_OFFSET) == rest.bytesize
          end
        end

        private_class_method :after_id3v2, :frame_at, :measure, :clean_end?, :id3v1?, :ape_to_end?
      end

      # MP4 : les boîtes de premier niveau, puis moov → mvhd, trak/mdia/mdhd, trak/mdia/minf/stbl/stts.
      module Mp4
        BOX_HEADER_BYTES = 8
        LARGE_BOX_HEADER_BYTES = 16
        SIZE_TO_END = 0
        SIZE_64_BITS = 1
        ENTRY_BYTES = 8
        STTS_HEADER_BYTES = 8
        SIZES_BYTES = 12
        HEADER_V0_BYTES = 20
        HEADER_V1_BYTES = 32

        # → le plus grand de mvhd, de chaque mdhd et de la somme de chaque stts (sur l'échelle de sa piste) ; nil sans moov.
        def self.seconds(bytes)
          movies = []
          each_box(bytes, 0, bytes.bytesize) do |type, from, to|
            throw :unreadable if type == "moof"
            movies << [ from, to ] if type == "moov"
          end
          movies.flat_map { |from, to| movie_seconds(bytes, from, to) }.max
        end

        # Chaque boîte avance d'au moins 8 octets ou rend le fichier illisible (taille < 8, au-delà du parent, en-tête coupé).
        def self.each_box(bytes, from, to)
          pos = from
          while pos < to
            throw :unreadable if to - pos < BOX_HEADER_BYTES

            size = bytes.unpack1("N", offset: pos)
            header = BOX_HEADER_BYTES
            if size == SIZE_64_BITS
              throw :unreadable if to - pos < LARGE_BOX_HEADER_BYTES

              size = bytes.unpack1("Q>", offset: pos + BOX_HEADER_BYTES)
              header = LARGE_BOX_HEADER_BYTES
            elsif size == SIZE_TO_END
              size = to - pos
            end
            throw :unreadable if size < header || size > to - pos

            yield bytes.byteslice(pos + 4, 4), pos + header, pos + size
            pos += size
          end
        end

        def self.movie_seconds(bytes, from, to)
          seconds = []
          each_box(bytes, from, to) do |type, start, stop|
            case type
            when "mvex" then throw :unreadable
            when "mvhd" then seconds << header_seconds(bytes, start, stop)
            when "trak" then seconds.concat(track_seconds(bytes, start, stop))
            end
          end
          seconds
        end

        # Une piste sans mdhd ou sans mdia/minf/stbl/stts n'a qu'une durée déclarée, invérifiable : illisible.
        def self.track_seconds(bytes, from, to)
          mdhd = descend(bytes, from, to, %w[mdia mdhd])
          stbl = descend(bytes, from, to, %w[mdia minf stbl])
          stts = stbl && descend(bytes, *stbl, %w[stts])
          throw :unreadable if mdhd.nil? || stts.nil?

          timescale, duration = header(bytes, *mdhd)
          [ duration.fdiv(timescale), ticks(bytes, *stts, sample_count(bytes, *stbl)).fdiv(timescale) ]
        end

        # Le nombre d'échantillons de la piste : stsz ou stz2 (version et drapeaux, taille, nombre). Sans l'un des deux, la
        # table stts n'est pas vérifiable : illisible.
        def self.sample_count(bytes, from, to)
          sizes = descend(bytes, from, to, %w[stsz]) || descend(bytes, from, to, %w[stz2])
          throw :unreadable if sizes.nil? || sizes.last - sizes.first < SIZES_BYTES

          bytes.unpack1("N", offset: sizes.first + 8)
        end

        # La première boîte du chemin (type par type), ou nil.
        def self.descend(bytes, from, to, path)
          found = nil
          each_box(bytes, from, to) do |type, start, stop|
            next unless found.nil? && type == path.first

            found = path.one? ? [ start, stop ] : descend(bytes, start, stop, path.drop(1))
          end
          found
        end

        # mvhd et mdhd : version et drapeaux (4), dates, échelle de temps, durée ; dates et durée en 64 bits si version 1.
        def self.header(bytes, from, to)
          version = bytes.getbyte(from)
          throw :unreadable unless [ 0, 1 ].include?(version)
          throw :unreadable if to - from < (version.zero? ? HEADER_V0_BYTES : HEADER_V1_BYTES)

          timescale, duration = version.zero? ? bytes.unpack("NN", offset: from + 12) : [ bytes.unpack1("N", offset: from + 20), bytes.unpack1("Q>", offset: from + 24) ]
          throw :unreadable if timescale.zero?

          [ timescale, duration ]
        end

        def self.header_seconds(bytes, from, to)
          timescale, duration = header(bytes, from, to)
          duration.fdiv(timescale)
        end

        # La somme (échantillons × durée) de la table stts. Le nombre d'entrées annoncé doit correspondre exactement aux octets
        # de la boîte, et les échantillons comptés doivent être ceux de la piste (stsz) : sinon illisible.
        def self.ticks(bytes, from, to, expected_samples)
          throw :unreadable if to - from < STTS_HEADER_BYTES
          throw :unreadable unless bytes.unpack1("N", offset: from + 4) * ENTRY_BYTES == to - from - STTS_HEADER_BYTES

          entries = bytes.byteslice(from + STTS_HEADER_BYTES, to - from - STTS_HEADER_BYTES).unpack("N*").each_slice(2).to_a
          throw :unreadable unless entries.sum(&:first) == expected_samples

          entries.sum { |samples, delta| samples * delta }
        end

        private_class_method :each_box, :movie_seconds, :track_seconds, :descend, :header, :header_seconds, :ticks, :sample_count
      end
    end
  end
end
