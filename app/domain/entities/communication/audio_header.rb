# 🧠 DOMAINE · Entities::Communication::AudioHeader
# Rôle : lit le format d'un fichier audio dans ses premiers octets, sans bibliothèque : MP3 ou M4A, sinon nil
# ADR  : 0045, 0078, 0081
module Entities
  module Communication
    # ADR-0081 §4.4 : les enregistrements des téléphones. Un MP3 commence par une étiquette ID3, ou par une trame MPEG
    # valide, au début ou après des octets nuls de remplissage ; un M4A (MP4 ou 3GP) par une boîte ftyp d'une marque
    # connue. AMR (« #!AMR »), OGG (« OggS »), WAV (« RIFF…WAVE ») et tout le reste : nil.
    module AudioHeader
      ID3 = "ID3".b.freeze
      FTYP = "ftyp".b.freeze
      # Marques majeures de la boîte ftyp, selon le téléphone ou le logiciel qui a enregistré.
      MP4_BRANDS = [ "M4A ", "M4B ", "mp41", "mp42", "isom", "iso2", "3gp4", "3gp5", "3gp6", "3g2a", "MSNV", "dash",
                     "f4a " ].freeze
      # Le premier octet qui n'est pas un remplissage nul ; cherché par une expression, sans boucle octet par octet.
      NOT_PADDING = /[^\x00]/n
      # En-tête d'une trame MPEG audio, 32 bits : AAAAAAAA AAABBCCD EEEEFFGH IIJJKLMM (A synchro, B version, C couche,
      # E débit, F fréquence).
      FRAME_HEADER_BYTES = 4
      SYNC = 0x7FF
      RESERVED_VERSION = 0b01
      RESERVED_LAYER = 0b00
      # Débit 0 : « libre », la longueur des trames ne se lit pas dans l'en-tête ; 15 : réservé.
      REFUSED_BITRATES = [ 0b0000, 0b1111 ].freeze
      RESERVED_SAMPLE_RATE = 0b11

      # bytes : String, les premiers octets du fichier (MessageInput en lit HEADER_BYTES, 4096) → :mpeg, :mp4 ou nil.
      # Fonction pure : les octets reçus ne sont pas modifiés.
      def self.format_of(bytes)
        bytes = bytes.to_s.b
        return :mpeg if bytes.start_with?(ID3) || frame_after_padding?(bytes)
        return :mp4 if bytes.byteslice(4, 4) == FTYP && MP4_BRANDS.include?(bytes.byteslice(8, 4))

        nil
      end

      # Une trame entière (4 octets) au premier octet non nul ; un remplissage qui va jusqu'au bout n'en a pas.
      def self.frame_after_padding?(bytes)
        start = bytes.index(NOT_PADDING)
        return false if start.nil?

        header = bytes.byteslice(start, FRAME_HEADER_BYTES)
        return false if header.bytesize < FRAME_HEADER_BYTES

        frame?(header.unpack1("N"))
      end

      def self.frame?(word)
        (word >> 21) == SYNC &&
          ((word >> 19) & 0b11) != RESERVED_VERSION &&
          ((word >> 17) & 0b11) != RESERVED_LAYER &&
          !REFUSED_BITRATES.include?((word >> 12) & 0b1111) &&
          ((word >> 10) & 0b11) != RESERVED_SAMPLE_RATE
      end

      private_class_method :frame_after_padding?, :frame?
    end
  end
end
