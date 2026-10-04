require "test_helper"

module Entities
  module Communication
    # ADR-0069 §6 (ADR-0045 §4) : le format d'un audio se lit dans ses premiers octets, sans bibliothèque ; seuls MP3 et
    # M4A passent, quelle que soit l'extension annoncée.
    class AudioHeaderTest < ActiveSupport::TestCase
      def bytes(*values, tail: "") = values.pack("C*") + tail.b

      test "un MP3 qui commence par une étiquette ID3 est un audio/mpeg" do
        assert_equal :mpeg, AudioHeader.format_of("ID3".b + bytes(0x04, 0x00, 0x00, tail: "\x00" * 16))
      end

      test "un MP3 sans étiquette, qui commence par une synchro de trame, est un audio/mpeg" do
        assert_equal :mpeg, AudioHeader.format_of(bytes(0xFF, 0xFB, 0x90, 0x64))
        assert_equal :mpeg, AudioHeader.format_of(bytes(0xFF, 0xE3, 0x18, 0xC4))
      end

      test "un octet 0xFF sans les trois bits de synchro qui suivent n'est pas une trame" do
        assert_nil AudioHeader.format_of(bytes(0xFF, 0xD8, 0xFF, 0xE0))
        assert_nil AudioHeader.format_of(bytes(0xFF))
      end

      test "un M4A (boîte ftyp de marque M4A, mp42 ou isom) est un audio/mp4" do
        %w[M4A\  mp42 isom].each do |brand|
          assert_equal :mp4, AudioHeader.format_of(bytes(0x00, 0x00, 0x00, 0x20, tail: "ftyp#{brand}\x00\x00\x02\x00")), brand
        end
      end

      test "une boîte ftyp d'une autre marque n'est pas un M4A" do
        assert_nil AudioHeader.format_of(bytes(0x00, 0x00, 0x00, 0x20, tail: "ftypqt  \x00\x00\x02\x00"))
      end

      test "un WAV, un PDF, une image, une chaîne vide ou rien sont refusés" do
        assert_nil AudioHeader.format_of("RIFF\x24\x08\x00\x00WAVEfmt ".b)
        assert_nil AudioHeader.format_of("%PDF-1.7\n%".b)
        assert_nil AudioHeader.format_of("\x89PNG\r\n\x1A\n".b)
        assert_nil AudioHeader.format_of("")
        assert_nil AudioHeader.format_of(nil)
      end

      test "une chaîne non binaire est lue octet par octet" do
        assert_equal :mpeg, AudioHeader.format_of(+"ID3 étiquette")
      end
    end
  end
end
