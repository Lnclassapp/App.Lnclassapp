# 🧠 DOMAINE · Entities::Classroom::JoinCode
# Rôle : code d'adhésion d'une classe : 3 lettres puis 2 chiffres, sans i, o, 0 ni 1
# ADR  : 0041
module Entities
  module Classroom
    module JoinCode
      LETTERS = (("a".."z").to_a - %w[i o]).freeze
      DIGITS = ("2".."9").to_a.freeze
      LETTER_COUNT = 3
      LENGTH = 5
      FORMAT = /\A[a-hj-np-z]{3}[2-9]{2}\z/
      SPACE = (LETTERS.size**LETTER_COUNT) * (DIGITS.size**(LENGTH - LETTER_COUNT))

      def self.generate(random: SecureRandom)
        letters = Array.new(LETTER_COUNT) { LETTERS.sample(random:) }
        digits = Array.new(LENGTH - LETTER_COUNT) { DIGITS.sample(random:) }
        (letters + digits).join
      end

      # Tire `count` codes distincts, absents de `taken` (Set), qu'il complète.
      def self.generate_unique(count:, taken:, random: SecureRandom)
        raise ArgumentError, "plus assez de codes d'adhésion libres" if count > SPACE - taken.size

        Array.new(count) do
          code = generate(random:)
          code = generate(random:) while taken.include?(code)
          taken << code
          code
        end
      end

      def self.normalize(raw) = raw.to_s.gsub(/\s+/, "").downcase
      def self.valid?(code) = FORMAT.match?(code.to_s)
      def self.display(code) = code&.upcase
    end
  end
end
