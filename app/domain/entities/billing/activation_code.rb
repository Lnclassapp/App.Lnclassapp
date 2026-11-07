# 🧠 DOMAINE · Entities::Billing::ActivationCode
# Rôle : le code d'une carte, 12 signes tirés sur 31 (sans 0, O, 1, I, L), saisie normalisée, affichage XXXX-XXXX-XXXX
# ADR  : 0126 (contexte billing, §4.2)
module Entities
  module Billing
    module ActivationCode
      ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".freeze
      LENGTH = 12
      GROUP = 4

      def self.generate = Array.new(LENGTH) { ALPHABET[SecureRandom.random_number(ALPHABET.length)] }.join

      # Majuscules, sans espace ni tiret.
      def self.normalize(raw) = raw.to_s.upcase.gsub(/[\s-]/, "")

      def self.format(code) = code.to_s.scan(/.{1,#{GROUP}}/).join("-")

      # Un code normalisé : évite une recherche en base pour une saisie qui ne peut pas exister.
      def self.well_formed?(code) = code.match?(/\A[#{ALPHABET}]{#{LENGTH}}\z/)
    end
  end
end
