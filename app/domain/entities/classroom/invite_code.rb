# 🧠 DOMAINE · Entities::Classroom::InviteCode
# Rôle : code d'invitation d'un élève, 8 symboles de l'alphabet des codes de classe, minuscules, tiré au hasard (aléa injecté)
# ADR  : attribution-des-inscriptions-eleves (§4.3) · alphabet de Entities::Classroom::JoinCode
module Entities
  module Classroom
    module InviteCode
      ALPHABET = JoinCode::SYMBOLS
      LENGTH = 8
      FORMAT = /\A[a-hjkmnp-z2-9]{8}\z/

      def self.generate(random: SecureRandom) = Array.new(LENGTH) { ALPHABET.sample(random:) }.join

      # Saisie tolérante : « K7M 4Q2Z » → « k7m4q2z » ; vide → nil.
      def self.normalize(raw)
        code = raw.to_s.gsub(/\s+/, "").downcase
        code.empty? ? nil : code
      end

      def self.valid?(code) = FORMAT.match?(code.to_s)
    end
  end
end
