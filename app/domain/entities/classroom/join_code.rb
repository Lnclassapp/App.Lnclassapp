# 🧠 DOMAINE · Entities::Classroom::JoinCode
# Rôle : code de classe : 6 symboles parmi 31 (sans i, l, o, 0 ni 1), stocké en minuscules, affiché « K7M 4Q2 », saisi sans égard à la casse
# ADR  : XXXX-code-de-classe-a-six-caracteres (§4) · calqué sur Entities::School::SchoolCode
module Entities
  module Classroom
    module JoinCode
      SYMBOLS = ((("a".."z").to_a - %w[i l o]) + ("2".."9").to_a).freeze
      LENGTH = 6
      FORMAT = /\A[a-hjkmnp-z2-9]{6}\z/
      SPACE = SYMBOLS.size**LENGTH
      GROUP = 3
      # ADR-XXXX §4.2 : essais en cas de collision avant d'abandonner.
      ATTEMPTS = 5

      # Aucun code libre trouvé en ATTEMPTS essais : l'appelant décide (réessayer l'écriture, remonter l'erreur).
      class Exhausted < StandardError; end

      def self.generate(random: SecureRandom) = Array.new(LENGTH) { SYMBOLS.sample(random:) }.join

      # Tire des codes jusqu'à ce que le bloc dise « pris » faux (`taken.call(code)`) ; ATTEMPTS essais au plus.
      def self.generate_free(random: SecureRandom, attempts: ATTEMPTS)
        attempts.times do
          code = generate(random:)
          return code unless yield(code)
        end
        raise Exhausted, "aucun code de classe libre en #{attempts} essais"
      end

      # Saisie tolérante : « k7m 4Q2 », « K7M-4Q2 » → « k7m4q2 ».
      def self.normalize(raw) = raw.to_s.gsub(/[\s-]+/, "").downcase
      def self.valid?(code) = FORMAT.match?(code.to_s)

      def self.display(code)
        code && "#{code[0, GROUP]} #{code[GROUP..]}".upcase
      end
    end
  end
end
