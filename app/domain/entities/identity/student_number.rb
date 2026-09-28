# 🧠 DOMAINE · Entities::Identity::StudentNumber
# Rôle : matricule MENA de l'élève : 8 chiffres et une lettre, normalisé en majuscules, masqué hors des écrans qui l'exigent
# ADR  : 0065 · UDR : 0052, 0053
module Entities
  module Identity
    module StudentNumber
      FORMAT = /\A[0-9]{8}[A-Z]\z/
      SEPARATORS = %r{[\s./-]+}
      VISIBLE = 5

      # « 1234 5678-a » → « 12345678A » ; vide → nil
      def self.normalize(raw) = raw.to_s.gsub(SEPARATORS, "").upcase.presence
      def self.valid?(value) = FORMAT.match?(value.to_s)
      def self.mask(value) = value && "••••#{value[-VISIBLE..]}"
    end
  end
end
