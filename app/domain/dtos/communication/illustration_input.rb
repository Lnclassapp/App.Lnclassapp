# 🧠 DOMAINE · Dtos::Communication::IllustrationInput
# Rôle : la saisie d'une illustration de l'équipe : son nom (30), et à l'ajout le fichier SVG, pesé avant toute lecture (50 Ko)
# ADR  : 0081 (§4.3) · UDR : 0075 (§3.5)
module Dtos
  module Communication
    # Le fichier n'est validé qu'à l'ajout (valid?(:add)) : le renommage ne porte que le nom. Les raisons de la lecture du
    # dessin (:unsafe, :not_svg, :empty) se rédigent comme celles du fichier, sous la même clé.
    class IllustrationInput
      include ActiveModel::Model

      ILLUSTRATION = Entities::Communication::Illustration

      # file : tout objet qui répond à size, read et rewind (fichier téléversé, StringIO), ou nil.
      attr_accessor :file
      attr_writer :name

      validates :name, presence: true, length: { maximum: ILLUSTRATION::NAME_MAX }
      validate :file_is_light, on: :add

      def name = @name.to_s.squish

      # Les octets du fichier, après valid?(:add) : jamais plus de MAX_BYTES, même d'un flux au poids annoncé trompeur.
      def bytes
        file.rewind
        file.read(ILLUSTRATION::MAX_BYTES).to_s.b
      end

      private

      # Le poids est vérifié avant toute lecture : un fichier trop lourd n'est jamais lu.
      def file_is_light
        return errors.add(:file, :blank) if file.nil?

        errors.add(:file, :too_heavy, count: ILLUSTRATION::MAX_BYTES / 1024) if file.size > ILLUSTRATION::MAX_BYTES
      end
    end
  end
end
