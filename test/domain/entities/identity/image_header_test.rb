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

      test "a JPEG without a frame before its scan, or with data after EOI, is no image" do
        jpeg = file_fixture("photos/photo.jpg").binread
        sof = jpeg.index("\xFF\xC0".b)
        without_frame = jpeg.byteslice(0, sof) + jpeg.byteslice(sof + 2 + jpeg.unpack1("n", offset: sof + 2)..)

        assert_nil ImageHeader.read(without_frame)
        assert_nil ImageHeader.read(jpeg + "tail")
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
        %w[photo_exif.jpg photo_exif.png photo_exif.webp].each do |name|
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
        %w[photo.jpg photo.png photo_lossy.webp photo_lossless.webp photo_alpha.webp document.pdf].each do |name|
          bytes = file_fixture("photos/#{name}").binread
          assert_equal bytes, ImageHeader.strip(bytes), name
        end
        assert_equal "\xFF\xD8".b, ImageHeader.strip("\xFF\xD8".b)
      end
    end
  end
end
