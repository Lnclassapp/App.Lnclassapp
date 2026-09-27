# 🔌 INFRA · Repositories::Catalog::RichTextSanitizer
# Rôle : assainit tout HTML écrit dans un contenu riche, importé ou saisi (liste blanche de Rails, sans pièce jointe)
# ADR  : 0039, 0049 · UDR : 0014
module Repositories
  module Catalog
    # Retire <script>, <style>, <iframe>, les attributs on*, les liens javascript: et les <action-text-attachment> :
    # la V1 n'accepte aucune pièce jointe, et Trix n'est pas un garde-fou pour une requête forgée.
    module RichTextSanitizer
      SANITIZER = Rails::HTML5::SafeListSanitizer.new

      # html : String | nil → String | nil. Loofah élague d'abord les balises dangereuses avec leur contenu,
      # pour qu'un <script> ne laisse pas son code en texte ; la liste blanche de Rails règle ensuite les attributs.
      def self.call(html)
        return if html.nil?

        SANITIZER.sanitize(Loofah.html5_fragment(html).scrub!(:prune).to_s)
      end
    end
  end
end
