# 🧠 DOMAINE · Entities::Communication::AudioHeader
# Rôle : lit le format d'un fichier audio dans ses premiers octets, sans bibliothèque : MP3 ou M4A, sinon nil
# ADR  : 0045, 0078
module Entities
  module Communication
    module AudioHeader
      ID3 = "ID3".b.freeze
      FTYP = "ftyp".b.freeze
      # Marques de la boîte ftyp d'un fichier M4A, selon le téléphone qui l'a enregistré.
      MP4_BRANDS = %w[M4A\  mp42 isom].freeze

      # bytes : String (les premiers octets suffisent) → :mpeg, :mp4 ou nil (WAV, PDF, image, vide…).
      def self.format_of(bytes)
        bytes = bytes.to_s.b
        # MP3 : étiquette ID3, ou synchro de trame (11 bits à 1) dès le premier octet.
        return :mpeg if bytes.start_with?(ID3) || (bytes.getbyte(0) == 0xFF && bytes.getbyte(1).to_i & 0xE0 == 0xE0)
        return :mp4 if bytes.byteslice(4, 4) == FTYP && MP4_BRANDS.include?(bytes.byteslice(8, 4))

        nil
      end
    end
  end
end
