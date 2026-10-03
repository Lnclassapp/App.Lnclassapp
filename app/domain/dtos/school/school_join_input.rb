# 🧠 DOMAINE · Dtos::School::SchoolJoinInput
# Rôle : code d'établissement saisi sur l'écran d'attente par un enseignant sans établissement, normalisé comme à l'inscription
# ADR  : 0057, 0071 · UDR : 0056
module Dtos
  module School
    class SchoolJoinInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :school_code, :string

      validate :school_code_well_formed

      # « k7m 4QZ » → « k7m4qz » ; la saisie brute reste pour le re-rendu (et le pré-remplissage du lien /e/<code>).
      def school_code=(raw)
        @raw_school_code = raw.to_s
        super(Entities::School::SchoolCode.normalize(raw))
      end

      def raw_school_code = @raw_school_code.to_s
      def to_h = { school_code: }

      private

      # La forme seule, sans recherche, avec les motifs de l'inscription enseignant (ADR-0057).
      def school_code_well_formed
        return errors.add(:school_code, :blank) if school_code.blank?
        return if Entities::School::SchoolCode.valid?(school_code)

        errors.add(:school_code, Entities::School::SchoolCode.classroom_code?(school_code) ? :classroom_code : :invalid)
      end
    end
  end
end
