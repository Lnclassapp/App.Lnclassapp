require "test_helper"

module Entities
  module Communication
    # ADR « annonces audio dix secondes » §4.2 et §4.4 (menaces M1 à M6), critères LA-2 et LA-3 : la durée d'un audio se
    # mesure dans ses octets. Fichiers réels de test/fixtures/files/audio (README.txt) ; les fichiers forgés des menaces
    # sont construits ici, octet par octet.
    class AudioDurationTest < ActiveSupport::TestCase
      # Une trame MPEG-2 couche III, 16 kHz, 32 kbit/s : 144 octets, 576 échantillons, 36 ms.
      def header(version: 2, layer: 3, bitrate: 4, rate: 2, padding: 0)
        word = (0x7FF << 21) | (version << 19) | ((4 - layer) << 17) | (1 << 16) | (bitrate << 12) | (rate << 10) | (padding << 9)
        [ word ].pack("N")
      end

      def frame(**) = header(**) + ("\x00".b * 140)

      def frames(count, **) = (frame(**) * count)

      def mp3(bytes) = AudioDuration.seconds_of(bytes, format: :mpeg)

      def mp4(bytes) = AudioDuration.seconds_of(bytes, format: :mp4)

      def recording(name) = file_fixture("audio/#{name}").binread

      def syncsafe(size) = [ (size >> 21) & 0x7F, (size >> 14) & 0x7F, (size >> 7) & 0x7F, size & 0x7F ].pack("C4")

      def zeros(count) = ("\x00".b * count)

      # ---- MP3

      test "LA-2 — real recordings: 9 s and 11 s, in MP3 and M4A, are measured within an encoder delay" do
        { "duree-9s.mp3" => 9, "duree-11s.mp3" => 11, "duree-9s.m4a" => 9, "duree-11s.m4a" => 11, "trame.mp3" => 1,
          "remplissage.mp3" => 1, "marque-isom.m4a" => 1, "marque-3gp4.m4a" => 1 }.each do |name, expected|
          format = AudioHeader.format_of(recording(name).byteslice(0, 4096))

          assert_in_delta expected, AudioDuration.seconds_of(recording(name), format:), 0.2, name
        end
      end

      test "an unknown format is not measured" do
        assert_nil AudioDuration.seconds_of(frames(3), format: :ogg)
      end

      test "frames are added one by one: 250 frames of 36 ms last 9 s" do
        assert_in_delta 9.0, mp3(frames(250)), 0.0001
      end

      test "M1 — an Xing or VBRI header that announces 10 frames, over 1000 real ones: the frames are added, the header is not believed" do
        %w[Xing VBRI].each do |tag|
          lying = header + zeros(32) + tag.b + [ 1, 10, 1440 ].pack("N3") + zeros(92)

          assert_in_delta 36.0, mp3(lying + frames(999)), 0.0001, tag
        end
      end

      test "M2 — unknown bytes between two frames make the duration unreadable, even when frames resume" do
        assert_nil mp3(frames(2) + "\x01\x02\x03".b + frames(2000))
        assert_nil mp3(frames(2) + zeros(4) + "ab".b + frames(2))
      end

      test "an ID3v2 tag is skipped by its syncsafe size, plus 10 bytes when it has a footer" do
        tag = "ID3\x04\x00\x00".b + syncsafe(300) + zeros(300)
        footer = "ID3\x04\x00\x10".b + syncsafe(5) + ("x".b * 5) + "3DI\x04\x00\x10".b + syncsafe(5)

        assert_in_delta 0.036 * 3, mp3(tag + frames(3)), 0.0001
        assert_in_delta 0.036 * 3, mp3(footer + frames(3)), 0.0001
      end

      test "an ID3v2 tag that is cut, not syncsafe, or longer than the file is unreadable" do
        assert_nil mp3("ID3\x04\x00".b)
        assert_nil mp3("ID3\x04\x00\x00".b + "\x00\x00\x02\x80".b + frames(3))
        assert_nil mp3("ID3\x04\x00\x00".b + syncsafe(5000) + frames(3))
      end

      test "null padding before the first frame is skipped; padding alone, an empty file or no frame is unreadable" do
        assert_in_delta 0.036 * 2, mp3(zeros(512) + frames(2)), 0.0001
        assert_nil mp3(zeros(512))
        assert_nil mp3("")
        assert_nil mp3(nil)
        assert_nil mp3("TAG".b + zeros(125))
        assert_nil mp3("ID3\x04\x00\x00".b + syncsafe(0))
      end

      test "the admitted ends are the end of the file, null bytes, an ID3v1 tag and an APE tag; any other byte is refused" do
        base = 0.036 * 3

        assert_in_delta base, mp3(frames(3)), 0.0001
        assert_in_delta base, mp3(frames(3) + zeros(40)), 0.0001
        assert_in_delta base, mp3(frames(3) + "TAG".b + ("a".b * 125)), 0.0001
        assert_in_delta base, mp3(frames(3) + "APETAGEX".b + ("a".b * 24)), 0.0001
        assert_nil mp3(frames(3) + "RIFF".b + zeros(40))
        assert_nil mp3(frames(3) + zeros(4) + "\x01".b)
        assert_nil mp3(frames(3) + "\xFF".b)
      end

      test "a last frame cut by the end of the file is counted" do
        assert_in_delta 0.036 * 3, mp3(frames(2) + frame.byteslice(0, 50)), 0.0001
        assert_in_delta 0.036 * 3, mp3(frames(2) + header), 0.0001
      end

      test "every version and layer is read with its own table: samples per frame over the sample rate" do
        {
          { version: 3, layer: 1, bitrate: 1, rate: 1 } => 384 / 48_000.0,
          { version: 3, layer: 2, bitrate: 14, rate: 2 } => 1152 / 32_000.0,
          { version: 3, layer: 3, bitrate: 9, rate: 0 } => 1152 / 44_100.0,
          { version: 2, layer: 1, bitrate: 14, rate: 0 } => 384 / 22_050.0,
          { version: 2, layer: 2, bitrate: 3, rate: 1 } => 1152 / 24_000.0,
          { version: 2, layer: 3, bitrate: 1, rate: 2 } => 576 / 16_000.0,
          { version: 0, layer: 3, bitrate: 2, rate: 0 } => 576 / 11_025.0,
          { version: 0, layer: 3, bitrate: 2, rate: 1 } => 576 / 12_000.0,
          { version: 0, layer: 3, bitrate: 2, rate: 2 } => 576 / 8000.0
        }.each do |options, seconds|
          assert_in_delta seconds, mp3(header(**options)), 0.000001, options.inspect
        end
      end

      test "the length of a frame follows its layer, bitrate, sample rate and padding bit" do
        # MPEG-1 couche III, 128 kbit/s, 44,1 kHz : 417 octets, 418 avec le bit de remplissage ;
        # couche I, 416 kbit/s, 48 kHz : (12 × 416000 / 48000) × 4 = 416 octets, 420 avec le bit de remplissage.
        l3 = { version: 3, layer: 3, bitrate: 9, rate: 0 }
        l1 = { version: 3, layer: 1, bitrate: 13, rate: 1 }

        assert_in_delta 1152 / 44_100.0 * 3, mp3(header(**l3) + zeros(413) + header(**l3, padding: 1) + zeros(414) + header(**l3)), 0.000001
        assert_nil mp3(header(**l3) + zeros(412) + header(**l3))
        assert_in_delta 384 / 48_000.0 * 3, mp3(header(**l1) + zeros(412) + header(**l1, padding: 1) + zeros(416) + header(**l1)), 0.000001
        assert_nil mp3(header(**l1, padding: 1) + zeros(412) + header(**l1) + "\x01".b)
      end

      test "M5 — a free or reserved bitrate, a reserved version, layer or sample rate is not a frame" do
        [ { bitrate: 0 }, { bitrate: 15 }, { version: 1 }, { rate: 3 } ].each do |options|
          assert_nil mp3(header(**options) + zeros(400)), options.inspect
        end
        layer_zero = [ (0x7FF << 21) | (2 << 19) | (4 << 12) | (2 << 10) ].pack("N")
        assert_nil mp3(layer_zero + zeros(400))
        assert_nil mp3("\xFF\xE0\x00\x00".b)
      end

      # ---- M4A

      def box(type, payload = "".b) = [ payload.bytesize + 8 ].pack("N") + type.b + payload

      def header_box(type, timescale:, duration:, version: 0)
        return box(type, [ 0, 0, 0, timescale, duration ].pack("N5")) if version.zero?

        box(type, [ 1 << 24 ].pack("N") + [ 0, 0 ].pack("Q>2") + [ timescale ].pack("N") + [ duration ].pack("Q>"))
      end

      def stts(*entries, count: entries.size) = box("stts", [ 0, count ].pack("N2") + entries.flatten.pack("N*"))

      def track(timescale:, duration:, entries: nil, version: 0, count: nil)
        stbl = entries ? box("stbl", stts(*entries, count: count || entries.size)) : "".b
        box("trak", box("mdia", header_box("mdhd", timescale:, duration:, version:) + box("minf", stbl)))
      end

      def movie(*children) = box("moov", children.join)

      def file(*boxes) = box("ftyp", "M4A \x00\x00\x02\x00".b) + boxes.join

      test "an M4A is measured by the largest of mvhd, each mdhd and the sum of each stts over the timescale of its track" do
        assert_in_delta 5.0, mp4(file(movie(header_box("mvhd", timescale: 1000, duration: 5000)))), 0.0001
        assert_in_delta 7.0, mp4(file(movie(header_box("mvhd", timescale: 1000, duration: 5000, version: 1),
                                            track(timescale: 100, duration: 700, version: 1)))), 0.0001
        assert_in_delta 9.0, mp4(file(movie(header_box("mvhd", timescale: 1000, duration: 5000),
                                            track(timescale: 100, duration: 700, entries: [ [ 90, 10 ] ])))), 0.0001
        assert_in_delta 9.0, mp4(file(movie(track(timescale: 100, duration: 700, entries: [ [ 40, 10 ], [ 50, 10 ] ])))), 0.0001
      end

      test "M3 — an mvhd that says 1 s over a track of 60 s: the track wins" do
        long = track(timescale: 1000, duration: 1000, entries: [ [ 1000, 60 ] ])

        assert_in_delta 60.0, mp4(file(movie(header_box("mvhd", timescale: 1000, duration: 1000), long))), 0.0001
        assert_in_delta 60.0, mp4(file(movie(header_box("mvhd", timescale: 1000, duration: 1000),
                                             track(timescale: 1000, duration: 60_000)))), 0.0001
      end

      test "M4 — a fragmented M4A (mvex in moov, or a moof) is unreadable" do
        mvhd = header_box("mvhd", timescale: 1000, duration: 1000)

        assert_nil mp4(file(movie(mvhd, box("mvex", zeros(24)))))
        assert_nil mp4(file(movie(mvhd), box("moof", zeros(8))))
      end

      test "M5 — a box of size 3, 4 or 7, or cut inside its header, is unreadable" do
        mvhd = movie(header_box("mvhd", timescale: 1000, duration: 1000))

        [ 2, 3, 7 ].each { |size| assert_nil mp4(file(mvhd, [ size ].pack("N") + "free".b + zeros(8))), size }
        assert_nil mp4(file(mvhd, zeros(3)))
        assert_nil mp4(file(mvhd, [ 1 ].pack("N") + "free".b + zeros(2)))
        assert_nil mp4(file(mvhd, [ 1 ].pack("N") + "free".b + [ 15 ].pack("Q>")))
      end

      test "a box longer than its parent or than the file is unreadable" do
        assert_nil mp4(file(movie(header_box("mvhd", timescale: 1000, duration: 1000)).byteslice(0, 30)))
        assert_nil mp4(file(box("moov", [ 400 ].pack("N") + "mvhd".b + zeros(24))))
      end

      test "a box of size 0 runs to the end of its parent; a size of 1 reads 64 bits" do
        moov = movie(header_box("mvhd", timescale: 1000, duration: 3000))
        to_end = [ 0 ].pack("N") + "mdat".b + zeros(20)
        wide = [ 1 ].pack("N") + "free".b + [ 20 ].pack("Q>") + zeros(4)

        assert_in_delta 3.0, mp4(file(moov, to_end)), 0.0001
        assert_in_delta 3.0, mp4(file(wide, moov)), 0.0001
        zero_moov = [ 0 ].pack("N") + "moov".b + header_box("mvhd", timescale: 1000, duration: 4000)
        assert_in_delta 4.0, mp4(file(zero_moov)), 0.0001
      end

      test "no moov, a zero timescale, a short or unknown header: unreadable" do
        assert_nil mp4(file(box("mdat", zeros(20))))
        assert_nil mp4("")
        assert_nil mp4(file(movie(header_box("mvhd", timescale: 0, duration: 1000))))
        assert_nil mp4(file(movie(track(timescale: 0, duration: 1000))))
        assert_nil mp4(file(movie(box("mvhd", zeros(12)))))
        assert_nil mp4(file(movie(box("mvhd", "\x01\x00\x00\x00".b + zeros(20)))))
        assert_nil mp4(file(movie(box("mvhd", "\x02\x00\x00\x00".b + zeros(40)))))
      end

      test "a trak without mdhd adds nothing; a track without stts counts by its mdhd" do
        mvhd = header_box("mvhd", timescale: 1000, duration: 2000)
        double = box("trak", box("mdia", header_box("mdhd", timescale: 1000, duration: 1500) + header_box("mdhd", timescale: 1000, duration: 9000)))

        assert_in_delta 2.0, mp4(file(movie(mvhd, box("trak", box("tkhd", zeros(8)))))), 0.0001
        assert_in_delta 2.0, mp4(file(movie(mvhd, box("trak", box("mdia", box("minf")))), box("moov"))), 0.0001
        assert_in_delta 2.0, mp4(file(movie(mvhd, double))), 0.0001
      end

      test "M6 — an stts that announces 2^32 entries is bounded by the bytes of its box" do
        inflated = track(timescale: 1000, duration: 1000, entries: [ [ 1000, 3 ] ], count: 2**32 - 1)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        assert_in_delta 3.0, mp4(file(movie(inflated))), 0.0001
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 1
      end

      test "an stts box without its header is unreadable" do
        broken = box("trak", box("mdia", header_box("mdhd", timescale: 1000, duration: 1000) + box("minf", box("stbl", box("stts", zeros(4))))))

        assert_nil mp4(file(movie(broken)))
      end
    end
  end
end
