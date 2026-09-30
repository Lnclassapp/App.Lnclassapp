# 🔌 INFRA · Repositories::Catalog::RichTextSanitizer
# Rôle : assainit tout HTML écrit dans un contenu riche, importé ou saisi (liste blanche de Rails, sans pièce jointe)
# ADR  : 0039, 0049, 0068 · UDR : 0014
module Repositories
  module Catalog
    # Retire <script>, <style>, <iframe>, les attributs on*, les liens javascript: et les <action-text-attachment> :
    # la V1 n'accepte aucune pièce jointe, et Trix n'est pas un garde-fou pour une requête forgée.
    module RichTextSanitizer
      # Le filtre de Rails::HTML5::SafeListSanitizer, avec ses balises et attributs permis par défaut.
      SCRUBBER = Rails::HTML::PermitScrubber.new.tap do |scrubber|
        scrubber.tags = Rails::HTML5::SafeListSanitizer.allowed_tags
        scrubber.attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes
      end

      # html : String | nil → String | nil. Loofah élague d'abord les balises dangereuses avec leur contenu,
      # pour qu'un <script> ne laisse pas son code en texte ; la liste blanche de Rails règle ensuite les attributs.
      # Une seule analyse (ADR-0068 §4) : les deux filtres passent sur le même fragment.
      def self.call(html) = html && Loofah.html5_fragment(html).scrub!(:prune).scrub!(SCRUBBER).to_s
    end
  end
end
