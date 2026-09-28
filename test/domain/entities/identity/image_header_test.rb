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
        itxt = [ 5 ].pack("N") + "iTXt" + "XMP\0\0" + "\0\0\0\0"
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

      test "every prefix of every fixture reads without raising: a truncated header is no image, never an error" do
        Dir[File.join(file_fixture_path, "photos", "photo*")].each do |path|
          bytes = File.binread(path)
          (0..bytes.bytesize).each do |length|
            prefix = bytes.byteslice(0, length)
            facts = ImageHeader.read(prefix)

            assert(facts.nil? || facts.width.positive?, "#{File.basename(path)}[0, #{length}]")
            assert_kind_of String, ImageHeader.strip(prefix)
          end
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
