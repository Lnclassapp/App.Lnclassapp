# 🧠 DOMAINE · Entities::School::SchoolCode
# Rôle : code d'établissement de l'inscription enseignant : 6 symboles parmi 32 (sans i, o, 0 ni 1), affiché « K7M-4QZ »
# ADR  : 0057 · UDR : 0044
module Entities
  module School
    module SchoolCode
      SYMBOLS = ((("a".."z").to_a - %w[i o]) + ("2".."9").to_a).freeze
      LENGTH = 6
      FORMAT = /\A[a-hj-np-z2-9]{6}\z/
      SPACE = SYMBOLS.size**LENGTH
      GROUP = 3

      def self.generate(random: SecureRandom) = Array.new(LENGTH) { SYMBOLS.sample(random:) }.join

      # Tire `count` codes distincts, absents de `taken` (Set), qu'il complète.
      def self.generate_unique(count:, taken:, random: SecureRandom)
        raise ArgumentError, "plus assez de codes d'établissement libres" if count > SPACE - taken.size

        Array.new(count) do
          code = generate(random:)
          code = generate(random:) while taken.include?(code)
          taken << code
          code
        end
      end

      # Saisie tolérante : « k7m 4QZ », « K7M-4QZ » → « k7m4qz ».
      def self.normalize(raw) = raw.to_s.gsub(/[\s-]+/, "").downcase
      def self.valid?(code) = FORMAT.match?(code.to_s)

      # Un code de classe saisi par erreur : reconnu à sa forme, sans aucune recherche.
      def self.classroom_code?(code) = Entities::Classroom::JoinCode.valid?(code)

      def self.display(code)
        code && "#{code[0, GROUP]}-#{code[GROUP..]}".upcase
      end
    end
  end
end
