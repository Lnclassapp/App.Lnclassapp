require "test_helper"

module Entities
  module Communication
    # ADR-0081 §4.4 (amende l'ADR-0078 §4.4) : le format d'un audio se lit dans ses premiers octets, sans bibliothèque ;
    # seuls MP3 et M4A passent, quelle que soit l'extension annoncée. Un enregistrement réel par variante
    # (test/fixtures/files/audio/README.txt), lu comme MessageInput le lit : ses 4096 premiers octets.
    class AudioHeaderTest < ActiveSupport::TestCase
      HEADER_BYTES = Dtos::Communication::MessageInput::HEADER_BYTES
      # Une trame MPEG-1 couche III, 128 kbit/s, 44,1 kHz.
      FRAME = [ 0xFF, 0xFB, 0x90, 0x64 ].pack("C*").freeze

      def bytes(*values, tail: "") = values.pack("C*") + tail.b
      def header_of(name) = File.binread(file_fixture("audio/#{name}"), HEADER_BYTES)
      def padding(count) = "\x00".b * count

      test "AV-12 — un MP3 qui commence par une trame, sans étiquette ID3, est un audio/mpeg (trame.mp3)" do
        assert_equal :mpeg, AudioHeader.format_of(header_of("trame.mp3"))
      end

      test "AV-12 — un MP3 précédé de 512 octets nuls de remplissage est un audio/mpeg (remplissage.mp3)" do
        header = header_of("remplissage.mp3")

        assert_equal padding(512), header.byteslice(0, 512)
        assert_equal :mpeg, AudioHeader.format_of(header)
      end

      {
        "marque-m4a.m4a" => "M4A ", "marque-m4b.m4a" => "M4B ", "marque-mp41.m4a" => "mp41",
        "marque-mp42.m4a" => "mp42", "marque-isom.m4a" => "isom", "marque-3gp4.m4a" => "3gp4",
        "marque-3gp5.m4a" => "3gp5"
      }.each do |name, brand|
        test "AV-12 — un enregistrement AAC de marque « #{brand} » est un audio/mp4 (#{name})" do
          header = header_of(name)

          assert_equal "ftyp#{brand}", header.byteslice(4, 8), "la fixture porte bien sa marque"
          assert_equal :mp4, AudioHeader.format_of(header)
        end
      end

      { "enregistrement.amr" => "#!AMR", "enregistrement.ogg" => "OggS", "enregistrement.wav" => "RIFF" }.each do |name, magic|
        test "AV-12 — un enregistrement #{magic} est refusé (#{name})" do
          header = header_of(name)

          assert header.start_with?(magic), "la fixture est bien un #{magic}"
          assert_nil AudioHeader.format_of(header)
        end
      end

      test "AV-12 — un remplissage nul jusqu'à la fin des 4096 octets, sans trame, est refusé" do
        assert_nil AudioHeader.format_of(padding(HEADER_BYTES))
      end

      test "AV-12 — une trame à débit 15 (réservé) est refusée, au début comme après le remplissage" do
        { "trame.mp3" => 2, "remplissage.mp3" => 514 }.each do |name, bitrate_byte|
          header = header_of(name)
          header.setbyte(bitrate_byte, header.getbyte(bitrate_byte) | 0xF0)

          assert_nil AudioHeader.format_of(header), name
        end
      end

      test "AV-12 — une trame dont les 4 octets finissent au 4096ᵉ est lue ; coupée par la fin, elle est refusée" do
        assert_equal :mpeg, AudioHeader.format_of(padding(HEADER_BYTES - 4) + FRAME)
        assert_nil AudioHeader.format_of(padding(HEADER_BYTES - 2) + FRAME.byteslice(0, 2))
      end

      test "AV-12 — un remplissage suivi d'autre chose qu'une trame est refusé" do
        assert_nil AudioHeader.format_of(padding(16) + "\x89PNG\r\n\x1A\n".b)
        assert_nil AudioHeader.format_of(padding(16) + "OggS".b)
      end

      test "AV-12 — une trame de version, de couche, de débit ou de fréquence réservés, ou de débit libre, est refusée" do
        assert_nil AudioHeader.format_of(bytes(0xFF, 0xEB, 0x90, 0x64)), "version réservée (01)"
        assert_nil AudioHeader.format_of(bytes(0xFF, 0xF9, 0x90, 0x64)), "couche réservée (00)"
        assert_nil AudioHeader.format_of(bytes(0xFF, 0xFB, 0x00, 0x64)), "débit libre (0)"
        assert_nil AudioHeader.format_of(bytes(0xFF, 0xFB, 0xF0, 0x64)), "débit réservé (15)"
        assert_nil AudioHeader.format_of(bytes(0xFF, 0xFB, 0x9C, 0x64)), "fréquence réservée (11)"
      end

      test "AV-12 — toute marque majeure de l'ADR-0081 §4.4 est un audio/mp4, une autre est refusée" do
        %w[M4A\  M4B\  mp41 mp42 isom iso2 3gp4 3gp5 3gp6 3g2a MSNV dash f4a\ ].each do |brand|
          assert_equal :mp4, AudioHeader.format_of(bytes(0x00, 0x00, 0x00, 0x20, tail: "ftyp#{brand}\x00\x00\x02\x00")), brand
        end
        assert_nil AudioHeader.format_of(bytes(0x00, 0x00, 0x00, 0x20, tail: "ftypqt  \x00\x00\x02\x00"))
        assert_nil AudioHeader.format_of(bytes(0x00, 0x00, 0x00, 0x00, 0x20, tail: "ftypM4A \x00\x00\x02\x00")), "ftyp hors de l'octet 4"
      end

      test "un MP3 qui commence par une étiquette ID3 est un audio/mpeg" do
        assert_equal :mpeg, AudioHeader.format_of("ID3".b + bytes(0x04, 0x00, 0x00, tail: "\x00" * 16))
      end

      test "un MP3 sans étiquette, qui commence par une synchro de trame, est un audio/mpeg" do
        assert_equal :mpeg, AudioHeader.format_of(FRAME)
        assert_equal :mpeg, AudioHeader.format_of(bytes(0xFF, 0xE3, 0x18, 0xC4))
      end

      test "un octet 0xFF sans les trois bits de synchro qui suivent n'est pas une trame" do
        assert_nil AudioHeader.format_of(bytes(0xFF, 0xD8, 0xFF, 0xE0))
        assert_nil AudioHeader.format_of(bytes(0xFF))
      end

      test "un PDF, une image, une chaîne vide ou rien sont refusés" do
        assert_nil AudioHeader.format_of("%PDF-1.7\n%".b)
        assert_nil AudioHeader.format_of("\x89PNG\r\n\x1A\n".b)
        assert_nil AudioHeader.format_of("")
        assert_nil AudioHeader.format_of(nil)
      end

      test "une chaîne non binaire est lue octet par octet" do
        assert_equal :mpeg, AudioHeader.format_of(+"ID3 étiquette")
      end

      test "la lecture ne modifie pas les octets reçus" do
        header = header_of("remplissage.mp3")
        copy = header.dup

        AudioHeader.format_of(header)

        assert_equal copy, header
      end
    end
  end
end
