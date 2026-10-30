# 🧠 DOMAINE · Entities::Communication::AudioDuration
# Rôle : mesure la durée d'un audio MP3 ou M4A dans ses octets (trame par trame, boîte par boîte), sans bibliothèque
# ADR  : XXXX-annonces-audio-dix-secondes (§4.2, menace §4.4), 0045, 0078 · UDR : 0071 (§3.8)
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
        # Fins admises après la dernière trame : ID3v1 et APE. Tout autre octet est illisible.
        TRAILERS = [ "TAG".b, "APETAGEX".b ].freeze
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

        # Ce qui suit la dernière trame : des octets nuls jusqu'au bout, ou une étiquette de fin.
        def self.clean_end?(bytes, pos)
          rest = bytes.byteslice(pos..)
          TRAILERS.any? { rest.start_with?(it) } || !rest.match?(NOT_NULL)
        end

        private_class_method :after_id3v2, :frame_at, :measure, :clean_end?
      end

      # MP4 : les boîtes de premier niveau, puis moov → mvhd, trak/mdia/mdhd, trak/mdia/minf/stbl/stts.
      module Mp4
        BOX_HEADER_BYTES = 8
        LARGE_BOX_HEADER_BYTES = 16
        SIZE_TO_END = 0
        SIZE_64_BITS = 1
        ENTRY_BYTES = 8
        STTS_HEADER_BYTES = 8
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

        def self.track_seconds(bytes, from, to)
          mdhd = descend(bytes, from, to, %w[mdia mdhd])
          return [] if mdhd.nil?

          timescale, duration = header(bytes, *mdhd)
          seconds = [ duration.fdiv(timescale) ]
          stts = descend(bytes, from, to, %w[mdia minf stbl stts])
          seconds << (ticks(bytes, *stts).fdiv(timescale)) if stts
          seconds
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

        # La somme (échantillons × durée) de la table stts ; le nombre d'entrées annoncé est borné par les octets de la boîte.
        def self.ticks(bytes, from, to)
          throw :unreadable if to - from < STTS_HEADER_BYTES

          count = [ bytes.unpack1("N", offset: from + 4), (to - from - STTS_HEADER_BYTES) / ENTRY_BYTES ].min
          bytes.byteslice(from + STTS_HEADER_BYTES, count * ENTRY_BYTES).unpack("N*").each_slice(2).sum { |samples, delta| samples * delta }
        end

        private_class_method :each_box, :movie_seconds, :track_seconds, :descend, :header, :header_seconds, :ticks
      end
    end
  end
end
