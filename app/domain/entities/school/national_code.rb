# 🧠 DOMAINE · Entities::School::NationalCode
# Rôle : code national d'un établissement (6 chiffres, public, publié avec les résultats du BEPC) ; désigne, ne prouve rien
# ADR  : 0063 · UDR : 0050
module Entities
  module School
    module NationalCode
      LENGTH = 6
      FORMAT = /\A\d{6}\z/

      # « 012 345 », « 012-345 » → « 012345 » ; un entier de l'import garde ses zéros (12345 → « 012345 ») ; vide → nil.
      def self.normalize(raw)
        return format("%0#{LENGTH}d", raw) if raw.is_a?(Integer) && raw.between?(0, (10**LENGTH) - 1)

        raw.to_s.gsub(/[\s-]+/, "").presence
      end

      def self.valid?(code) = FORMAT.match?(code.to_s)
    end
  end
end
