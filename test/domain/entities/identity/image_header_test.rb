require "test_helper"

# ADR-0060: the real format, the size and the shooting metadata of an image are read from its bytes, and the metadata
# removed, without any image library. Fixtures are encoded by real encoders (Pillow, libwebp), never hand-written.
module Entities
  module Identity
    class ImageHeaderTest < ActiveSupport::TestCase
      def facts(name) = ImageHeader.read(file_fixture("photos/#{name}").binread)

      test "a JPEG gives its size from its frame header; the JFIF segment is no metadata, an Exif segment is" do
        assert_equal ImageHeader::Facts.new(format: :jpeg, width: 64, height: 48, metadata: false), facts("photo.jpg")
        assert_equal ImageHeader::Facts.new(format: :jpeg, width: 64, height: 48, metadata: true), facts("photo_exif.jpg")
      end

      test "a PNG gives its size from IHDR; an eXIf chunk is metadata" do
        assert_equal ImageHeader::Facts.new(format: :png, width: 64, height: 48, metadata: false), facts("photo.png")
        assert_equal ImageHeader::Facts.new(format: :png, width: 64, height: 48, metadata: true), facts("photo_exif.png")
        assert_equal [ 1100, 8 ], facts("too_wide.png").then { [ it.width, it.height ] }
      end

      test "a WebP gives its size whether it is lossy, lossless or extended; an EXIF chunk is metadata" do
        %w[photo_lossy.webp photo_lossless.webp photo_alpha.webp].each do |name|
          assert_equal ImageHeader::Facts.new(format: :webp, width: 64, height: 48, metadata: false), facts(name), name
        end
        assert_equal ImageHeader::Facts.new(format: :webp, width: 64, height: 48, metadata: true), facts("photo_exif.webp")
      end

      test "XMP and IPTC segments of a JPEG, and an iTXt chunk of a PNG, are metadata too" do
        jpeg = file_fixture("photos/photo.jpg").binread
        [ "\xFF\xE1".b + [ 2 + 29 ].pack("n") + "http://ns.adobe.com/xap/1.0/\0".b,
          "\xFF\xED".b + [ 2 + 14 ].pack("n") + "Photoshop 3.0\0".b ].each do |segment|
          assert ImageHeader.read(jpeg.byteslice(0, 2) + segment + jpeg.byteslice(2..)).metadata
        end

        png = file_fixture("photos/photo.png").binread
        itxt = [ 5 ].pack("N") + "iTXt" + "XMP\0\0" + [ Zlib.crc32("iTXtXMP\0\0") ].pack("N")
        assert ImageHeader.read(png.byteslice(0, 33) + itxt + png.byteslice(33..)).metadata
      end

      test "a PDF, a text, an empty or a truncated file is no image" do
        jpeg = file_fixture("photos/photo.jpg").binread
        png = file_fixture("photos/photo.png").binread
        webp = file_fixture("photos/photo_lossy.webp").binread

        [ file_fixture("photos/document.pdf").binread, "hello", "", nil, jpeg.byteslice(0, 40), "\xFF\xD8\xFF\x00".b,
          png.byteslice(0, 20), png.byteslice(0, 8) + [ 13 ].pack("N") + "IHDX" + ("\0" * 17),
          webp.byteslice(0, 22), webp.byteslice(0, 12) + "ABCD" + [ 0 ].pack("V"), "\xFF\xD8\x00\x01\x02\x03".b,
          "\xFF\xD8\xFF\xC0\x00\x11\x08".b,
          "RIFF\x00\x00\x00\x00WEBPVP8L\x05\x00\x00\x00\x00\x00\x00\x00\x00".b ].each do |bytes|
          assert_nil ImageHeader.read(bytes), bytes.inspect
        end
      end

      # Fail closed (challenge of PR #50): an image is read only when its whole stream is well formed — the JPEG up to
      # EOI, the PNG up to IEND with valid CRCs, the WebP within its RIFF size. Every strict prefix is no image.
      test "every strict prefix of every fixture is no image, and reads without raising" do
        Dir[File.join(file_fixture_path, "photos", "photo*")].each do |path|
          bytes = File.binread(path)
          assert_not_nil ImageHeader.read(bytes), File.basename(path)
          (0...bytes.bytesize).each do |length|
            prefix = bytes.byteslice(0, length)

            assert_nil ImageHeader.read(prefix), "#{File.basename(path)}[0, #{length}]"
            assert_kind_of String, ImageHeader.strip(prefix)
          end
        end
      end

      test "hostile files of the challenge: a truncated, header-only or corrupt WebP is no image" do
        %w[truncated.webp bomb_header.webp corrupt.webp].each do |name|
          assert_nil facts("hostile/#{name}"), name
        end
      end

      test "a JPEG with fill bytes before its Exif is read, and strip removes the Exif; a stray byte makes it no image" do
        filled = file_fixture("photos/hostile/bypass_fill.jpg").binread

        assert facts("hostile/bypass_fill.jpg").metadata
        stripped = ImageHeader.strip(filled)
        assert_not_includes stripped, "Exif"
        assert_not_includes stripped, "SECRETCAM"
        assert_equal facts("hostile/bypass_fill.jpg").with(metadata: false), ImageHeader.read(stripped)
        assert_nil facts("hostile/bypass_exif.jpg")
      end

      # Allowlist (second challenge of PR #50): only the segments and chunks needed to draw the image are kept, rewritten
      # to their standard form when they have free fields; everything else leaves, whatever its name or signature.
      test "an ICC, Adobe or JFXX segment and a private or tIME PNG chunk carrying a secret leave nothing behind" do
        %w[app2_secret.jpg app14_secret.jpg jfxx_thumb_app0.jpg png_private_chunk.png].each do |name|
          original = file_fixture("photos/hostile/#{name}").binread
          stripped = ImageHeader.strip(original)

          assert facts("hostile/#{name}").metadata, name
          %w[SECRET GPS JFXX gpSx tIME ICC_PROFILE].each { assert_not_includes stripped, it, "#{name} garde #{it}" }
          assert_equal facts("hostile/#{name}").with(metadata: false), ImageHeader.read(stripped), name
        end
      end

      test "a JFIF segment is rewritten to its standard form, without its thumbnail; a standard Adobe segment is kept" do
        jpeg = file_fixture("photos/photo.jpg").binread
        app0 = jpeg.byteslice(2, 18)
        thumbnail = "\xFF\xE0".b + [ 16 + 3 ].pack("n") + "JFIF\0\x01\x02\x01\x00\x48\x00\x48\x01\x01SEC".b
        adobe = "\xFF\xEE\x00\x0EAdobe\x00\x64\x00\x00\x00\x00\x01".b
        with_thumbnail = jpeg.byteslice(0, 2) + thumbnail + jpeg.byteslice(20..)
        with_adobe = jpeg.byteslice(0, 20) + adobe + jpeg.byteslice(20..)

        assert ImageHeader.read(with_thumbnail).metadata
        assert_equal jpeg, ImageHeader.strip(with_thumbnail)
        assert_equal app0, ImageHeader.strip(with_thumbnail).byteslice(2, 18)
        assert_not ImageHeader.read(with_adobe).metadata
        assert_equal with_adobe, ImageHeader.strip(with_adobe)
      end

      test "the location of a PNG and of a WebP is removed with their metadata chunks" do
        %w[gps.png gps.webp].each do |name|
          stripped = ImageHeader.strip(file_fixture("photos/hostile/#{name}").binread)

          assert_not_includes stripped, "SECRETCAM", name
          assert_not ImageHeader.read(stripped).metadata, name
        end
      end

      # Fuzz: at every segment boundary of a JPEG — header, after the scan, before EOI — fill bytes, stray bytes or an
      # Exif segment must never survive strip: either the file is no image, or its stripped bytes carry no metadata.
      test "no fill byte, stray byte or Exif segment at any JPEG boundary lets metadata through" do
        exif = file_fixture("photos/photo_exif.jpg").binread.then { it.byteslice(it.index("\xFF\xE1".b), 2 + it.unpack1("n", offset: it.index("\xFF\xE1".b) + 2)) }
        inserts = [ "\xFF".b, "\xFF\xFF\xFF".b, "\x00".b, "A", "\xFF\x00".b, exif, "\xFF\xFF".b + exif, "\x00".b + exif ]

        %w[photo.jpg photo_exif.jpg portrait.jpg].each do |name|
          bytes = file_fixture("photos/#{name}").binread
          boundaries = (2...bytes.bytesize).select { bytes.getbyte(it) == 0xFF && ![ 0x00, 0xFF ].include?(bytes.getbyte(it + 1)) }
          boundaries.product(inserts).each do |at, insert|
            candidate = bytes.byteslice(0, at) + insert + bytes.byteslice(at..)
            next if ImageHeader.read(candidate).nil?

            stripped = ImageHeader.strip(candidate)
            assert_not_includes stripped, "Exif", "#{name} @#{at} #{insert.bytesize}"
            assert_not_includes stripped, "PhoneMaker", "#{name} @#{at}"
            assert_not ImageHeader.read(stripped).metadata, "#{name} @#{at}"
          end
        end
      end

      test "a JPEG without a frame before its scan is no image" do
        jpeg = file_fixture("photos/photo.jpg").binread
        sof = jpeg.index("\xFF\xC0".b)
        without_frame = jpeg.byteslice(0, sof) + jpeg.byteslice(sof + 2 + jpeg.unpack1("n", offset: sof + 2)..)

        assert_nil ImageHeader.read(without_frame)
      end

      test "a WebP reads its size past a foreign chunk; a too short VP8X or VP8, or a bad VP8L signature, is no image" do
        webp = file_fixture("photos/photo_lossy.webp").binread
        lossless = file_fixture("photos/photo_lossless.webp").binread
        riff = ->(body) { "RIFF".b + [ body.bytesize + 4 ].pack("V") + "WEBP" + body }
        chunk = ->(type, data) { type.b + [ data.bytesize ].pack("V") + data + ("\0" * (data.bytesize % 2)) }

        assert_equal [ 64, 48 ], ImageHeader.read(riff.(chunk.("ICCP", "abc") + webp.byteslice(12..))).then { [ it.width, it.height ] }
        [ riff.(chunk.("VP8X", "\0\0\0\0") + webp.byteslice(12..)), riff.(chunk.("VP8 ", "\0\0")),
          lossless.dup.tap { it.setbyte(20, 0x2E) }, riff.(webp.byteslice(12..) + "abc"),
          riff.(webp.byteslice(12..) + file_fixture("photos/photo_alpha.webp").binread.byteslice(12, 18)) ].each do |bytes|
          assert_nil ImageHeader.read(bytes)
        end
      end

      test "a PNG with a stray byte, trailing data, a bad CRC or no image data is no image" do
        png = file_fixture("photos/photo.png").binread
        idat = png.index("IDAT") - 4
        bad_crc = png.dup.tap { it.setbyte(idat - 1, it.getbyte(idat - 1) ^ 0xFF) }
        no_idat = png.byteslice(0, idat) + png.byteslice(png.index("IEND") - 4..)

        [ png.byteslice(0, idat) + "\x00" + png.byteslice(idat..), png + "tail", bad_crc, no_idat ].each do |bytes|
          assert_nil ImageHeader.read(bytes)
        end
      end

      test "a WebP with a chunk beyond its RIFF size, trailing data, no image chunk or a non-key frame is no image" do
        webp = file_fixture("photos/photo_lossy.webp").binread
        vp8x = file_fixture("photos/photo_alpha.webp").binread
        riff = ->(body) { "RIFF".b + [ body.bytesize + 4 ].pack("V") + "WEBP" + body }
        inter_frame = webp.dup.tap { it.setbyte(20, it.getbyte(20) | 0x01) }

        [ webp + "\0\0", riff.(webp.byteslice(12..) + "EXIF" + [ 99 ].pack("V")), riff.(vp8x.byteslice(12, 18)),
          inter_frame, riff.(webp.byteslice(12..) + webp.byteslice(12..)) ].each do |bytes|
          assert_nil ImageHeader.read(bytes)
        end
      end

      test "strip removes the Exif of a JPEG, a PNG and a WebP, and keeps the image and its size" do
        %w[photo_exif.jpg photo_exif.png photo_exif.webp photo_exif_lossless.webp].each do |name|
          original = file_fixture("photos/#{name}").binread
          stripped = ImageHeader.strip(original)

          assert_operator stripped.bytesize, :<, original.bytesize, name
          assert_equal facts(name).with(metadata: false), ImageHeader.read(stripped), name
          assert_not_includes stripped, "PhoneMaker", name
        end
        webp = ImageHeader.strip(file_fixture("photos/photo_exif.webp").binread)
        assert_equal webp.bytesize - 8, webp.unpack1("V", offset: 4)
        assert_equal 0, webp.getbyte(20) & 0x0C
      end

      test "strip leaves an image without metadata, and any other file, byte for byte" do
        %w[photo.jpg photo_progressive.jpg photo.png photo_palette.png photo_gray_trns.png photo_color.png photo_lossy.webp
           photo_lossless.webp photo_alpha.webp document.pdf].each do |name|
          bytes = file_fixture("photos/#{name}").binread
          assert_equal bytes, ImageHeader.strip(bytes), name
        end
        assert_equal "\xFF\xD8".b, ImageHeader.strip("\xFF\xD8".b)
      end

      # Challenge of PR #65: free bytes must not survive inside the kept parts either. Each hostile variant is built
      # from a real fixture; it is either no image, or its stripped bytes no longer carry the hidden bytes. Nothing
      # raises, and every variant is decided in well under 2 seconds.
      def refused_or_clean(variants)
        variants.each do |label, bytes|
          within_two_seconds(label) do
            facts = ImageHeader.read(bytes)
            next if facts.nil?

            stripped = ImageHeader.strip(bytes)
            assert_not_includes stripped, "SECRET", label
            assert_equal facts.with(metadata: false), ImageHeader.read(stripped), label
          end
        end
      end

      def assert_refused(label, bytes)
        within_two_seconds(label) do
          assert_nil ImageHeader.read(bytes), label
          assert_equal bytes.b, ImageHeader.strip(bytes), label
        end
      end

      def within_two_seconds(label)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 2, label
      end

      def png_chunk(type, data) = [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N")
      def riff(body) = "RIFF".b + [ body.bytesize + 4 ].pack("V") + "WEBP" + body
      def webp_chunk(type, data) = type.b + [ data.bytesize ].pack("V") + data + ("\0" * (data.bytesize % 2))
      def webp_chunks(name) = file_fixture("photos/#{name}").binread.byteslice(12..)

      # A JPEG segment rebuilt with its payload and its length recomputed.
      def jpeg_segment(marker, payload) = [ 0xFF, marker, payload.bytesize + 2 ].pack("CCn") + payload

      def with_segment(jpeg, marker, &)
        at = (2...jpeg.bytesize).find { jpeg.getbyte(it) == 0xFF && jpeg.getbyte(it + 1) == marker }
        length = jpeg.unpack1("n", offset: at + 2)
        jpeg.byteslice(0, at) + jpeg_segment(marker, yield(jpeg.byteslice(at + 4, length - 2))) + jpeg.byteslice(at + 2 + length..)
      end

      test "M1: a gAMA, sRGB or cHRM chunk longer than the standard, or an sRGB intent out of range, is no image" do
        png = file_fixture("photos/photo.png").binread
        insert = ->(type, data) { png.byteslice(0, 33) + png_chunk(type, data) + png.byteslice(33..) }

        assert_not_nil ImageHeader.read(insert.("gAMA", [ 45_455 ].pack("N")))
        { gama: insert.("gAMA", [ 45_455 ].pack("N") + "SECRET"), srgb: insert.("sRGB", "\0SECRET".b),
          srgb_intent: insert.("sRGB", "\x04".b), chrm: insert.("cHRM", ("\0" * 32) + "SECRET"),
          chrm_short: insert.("cHRM", "\0" * 31) }.each do |label, bytes|
          assert_refused(label, bytes)
        end
      end

      test "M1: a PLTE or tRNS chunk outside the bounds of the standard for the colour type is no image" do
        rgb = file_fixture("photos/photo.png").binread
        palette = file_fixture("photos/photo_palette.png").binread
        gray = file_fixture("photos/photo_gray_trns.png").binread
        replace = lambda do |png, type, data|
          at = png.index(type) - 4
          png.byteslice(0, at) + png_chunk(type, data) + png.byteslice(at + 12 + png.unpack1("N", offset: at)..)
        end
        insert = ->(png, type, data) { png.byteslice(0, 33) + png_chunk(type, data) + png.byteslice(33..) }

        assert_not_nil ImageHeader.read(insert.(rgb, "tRNS", "\0\x01\0\x02\0\x03".b))
        assert_not_nil ImageHeader.read(insert.(rgb, "PLTE", "\0" * 6))
        { plte_not_triplet: replace.(palette, "PLTE", "\0" * 47), plte_too_long: replace.(palette, "PLTE", "\0" * 771),
          plte_beyond_depth: replace.(palette, "PLTE", "\0" * 3 * 17), plte_empty: replace.(palette, "PLTE", ""),
          plte_in_gray: insert.(gray, "PLTE", "\0" * 3), no_plte: palette.sub(/....PLTE.*?(?=....tRNS)/mn, ""),
          trns_longer_than_palette: replace.(palette, "tRNS", "\0" * 17), trns_gray: replace.(gray, "tRNS", "\0\x11SECRET".b),
          trns_rgb: insert.(rgb, "tRNS", "\0\x01\0\x02\0\x03SECRET".b), trns_gray_high_byte: replace.(gray, "tRNS", "\x53\x11".b),
          trns_rgb_high_byte: insert.(rgb, "tRNS", "\0\x01\x53\x02\0\x03".b),
          trns_with_alpha: insert.(rgb.dup.tap { it.setbyte(25, 6) }.then { fix_ihdr(it) }, "tRNS", "\0") }.each do |label, bytes|
          assert_refused(label, bytes)
        end
      end

      test "M1: a chunk after the first IEND, a second IHDR or a non-empty IEND is no image" do
        png = file_fixture("photos/photo.png").binread
        idat = png.index("IDAT") - 4
        idat_chunk = png.byteslice(idat, 12 + png.unpack1("N", offset: idat))
        iend = png.bytesize - 12

        { idat_after_iend: png + idat_chunk + png_chunk("IEND", ""), iend_twice: png + png_chunk("IEND", ""),
          secret_after_iend: png + png_chunk("IDAT", "SECRET") + png_chunk("IEND", ""),
          iend_with_data: png.byteslice(0, iend) + png_chunk("IEND", "SECRET"),
          ihdr_twice: png.byteslice(0, 33) + png.byteslice(8, 25) + png.byteslice(33..) }.each do |label, bytes|
          assert_refused(label, bytes)
        end
      end

      test "M1: an IHDR with an unknown compression, filter or interlace method, or a bad depth for its colour type, is no image" do
        png = file_fixture("photos/photo.png").binread
        { depth: [ 24, 4 ], color: [ 25, 5 ], compression: [ 26, 1 ], filter: [ 27, 1 ], interlace: [ 28, 2 ] }.each do |label, (at, value)|
          assert_refused(label, fix_ihdr(png.dup.tap { it.setbyte(at, value) }))
        end
      end

      def fix_ihdr(png) = png.byteslice(0, 8) + png_chunk("IHDR", png.byteslice(16, 13)) + png.byteslice(33..)

      test "M2: a DQT, DHT, SOF, SOS, DRI or DAC segment longer than its tables, or a second frame, is no image" do
        jpeg = file_fixture("photos/photo.jpg").binread
        dri = jpeg.byteslice(0, 20) + jpeg_segment(0xDD, "\0\x10".b) + jpeg.byteslice(20..)
        assert_not_nil ImageHeader.read(dri)
        dac = jpeg.byteslice(0, 20) + jpeg_segment(0xCC, "\x00\x10".b) + jpeg.byteslice(20..)
        assert_not_nil ImageHeader.read(dac)
        sof = jpeg.index("\xFF\xC0".b)

        { dqt_long: with_segment(jpeg, 0xDB) { it + "SECRET" }, dqt_precision: with_segment(jpeg, 0xDB) { "\x20".b + it.byteslice(1..) },
          dqt_table: with_segment(jpeg, 0xDB) { "\x04".b + it.byteslice(1..) }, dqt_empty: with_segment(jpeg, 0xDB) { "" },
          dht_long: with_segment(jpeg, 0xC4) { it + "SECRET" }, dht_class: with_segment(jpeg, 0xC4) { "\x20".b + it.byteslice(1..) },
          dht_table: with_segment(jpeg, 0xC4) { "\x04".b + it.byteslice(1..) }, dht_counts: with_segment(jpeg, 0xC4) { it.byteslice(0, 10) },
          sof_long: with_segment(jpeg, 0xC0) { it + "SECRET" }, sos_long: with_segment(jpeg, 0xDA) { it + "SECRET" },
          sof_short: with_segment(jpeg, 0xC0) { it.byteslice(0, 4) }, zero_height: with_segment(jpeg, 0xC0) { it.byteslice(0, 1) + "\0\0" + it.byteslice(3..) },
          dri_long: with_segment(dri, 0xDD) { it + "SECRET" }, dac_odd: with_segment(dac, 0xCC) { it + "S" },
          dac_empty: with_segment(dac, 0xCC) { "" },
          two_frames: jpeg.byteslice(0, sof) + jpeg.byteslice(sof, 19) + jpeg.byteslice(sof..) }.each do |label, bytes|
          assert_refused(label, bytes)
        end
      end

      test "M1, M2: a VP8X longer than 10 bytes, a second VP8X or a non-zero padding byte is no image" do
        alpha = webp_chunks("photo_alpha.webp")
        vp8x = alpha.byteslice(0, 18)

        { vp8x_long: riff(webp_chunk("VP8X", alpha.byteslice(8, 10) + "SECRET") + alpha.byteslice(18..)),
          vp8x_twice: riff(alpha + vp8x), odd_padding: riff(webp_chunks("photo_lossy.webp") + webp_chunk("ICCP", "abc").tap { it.setbyte(-1, 0x53) }) }.each do |label, bytes|
          assert_refused(label, bytes)
        end
      end

      test "M1: the flags and reserved bytes of VP8X are rewritten to zero, the transparency flag aside" do
        alpha = file_fixture("photos/photo_alpha.webp").binread
        hidden = alpha.dup.tap { it.setbyte(20, 0xFF) }.tap { |b| (21..23).each { b.setbyte(it, 0x53) } }

        assert ImageHeader.read(hidden).metadata
        assert_equal alpha, ImageHeader.strip(hidden)
        refused_or_clean(vp8x_reserved: hidden)
      end

      test "M2: an ALPH chunk with a bad header, a raw alpha plane of the wrong size, twice or with a lossless image is no image" do
        alpha = webp_chunks("photo_alpha.webp")
        vp8x, alph, vp8 = alpha.byteslice(0, 18), alpha.byteslice(18, 28), alpha.byteslice(46..)
        header = ->(byte) { webp_chunk("ALPH", byte.chr + alph.byteslice(9, 19)) }
        raw = ->(size) { webp_chunk("ALPH", "\0" + ("\x80".b * size)) }
        lossless = webp_chunks("photo_lossless.webp")

        assert_not_nil ImageHeader.read(riff(vp8x + raw.(64 * 48) + vp8))
        assert_not_nil ImageHeader.read(riff(vp8x + header.(0x1D) + vp8))
        { compression: header.(0x02), preprocessing: header.(0x21), reserved: header.(0x41) + "", raw_long: raw.(64 * 48 + 6),
          raw_short: raw.(64 * 48 - 1), empty: webp_chunk("ALPH", "") }.each do |label, chunk|
          assert_refused(label, riff(vp8x + chunk + vp8))
        end
        { twice: riff(vp8x + alph + alph + vp8), after_image: riff(vp8x + vp8 + alph), with_lossless: riff(vp8x + alph + lossless),
          without_vp8x: riff(alph + vp8) }.each do |label, bytes|
          assert_refused(label, bytes)
        end
      end

      test "M3: a VP8X canvas that differs from the size of its VP8 or VP8L bitstream is no image" do
        alpha = file_fixture("photos/photo_alpha.webp").binread
        lossless = ImageHeader.strip(file_fixture("photos/photo_exif_lossless.webp").binread)

        assert_equal [ 64, 48 ], ImageHeader.read(lossless).then { [ it.width, it.height ] }
        [ alpha, lossless ].each do |webp|
          [ 24, 27 ].each { |at| assert_refused("#{webp.bytesize} @#{at}", webp.dup.tap { it.setbyte(at, it.getbyte(at) + 1) }) }
        end
      end

      test "M1: a VP8L with a non-zero version is no image" do
        lossless = file_fixture("photos/photo_lossless.webp").binread
        assert_refused(:vp8l_version, lossless.dup.tap { it.setbyte(24, it.getbyte(24) | 0x20) })
      end

      # M4 (decision of the coordinator): a smartphone JPEG carries a Motion Photo, an MPF secondary image or a gain map
      # after the EOI of its main stream. The file is accepted and everything after the first EOI is cut.
      test "M4: a JPEG with an MPF index and a secondary image after EOI is kept without them" do
        motion = file_fixture("photos/hostile/motion_photo_trailer.jpg").binread

        assert_equal ImageHeader::Facts.new(format: :jpeg, width: 64, height: 48, metadata: true), ImageHeader.read(motion)
        assert_equal file_fixture("photos/photo.jpg").binread, ImageHeader.strip(motion)
        assert_equal file_fixture("photos/photo.jpg").binread, ImageHeader.strip(file_fixture("photos/photo.jpg").binread + "tail")
        refused_or_clean(motion:, tail: file_fixture("photos/photo.jpg").binread + "SECRET")
      end
    end
  end
end
