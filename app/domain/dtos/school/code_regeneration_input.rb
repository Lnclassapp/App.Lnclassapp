# 🧠 DOMAINE · Dtos::School::CodeRegenerationInput
# Rôle : confirmation d'une régénération de masse : cible (codes ou liens), sélection, année en cours, nombre tapé
# ADR  : 0096 · UDR : 0104
module Dtos
  module School
    class CodeRegenerationInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      TARGETS = Entities::Catalog::ImportKind::CODE_REGENERATIONS

      attribute :target, :string
      attribute :typed_count, :string
      attribute :current_year_only, :boolean, default: true
      attribute :selection

      validates :target, inclusion: { in: TARGETS }

      # « 3 912 », « 3 912 » (espace fine), « 3.912 » → 3912 ; rien d'autre qu'un nombre → nil.
      def typed_count
        digits = super.to_s.gsub(/[\s.  ]/, "")
        digits.match?(/\A\d{1,7}\z/) ? digits.to_i : nil
      end

      def selection = SchoolSelection.from(super)
    end
  end
end
