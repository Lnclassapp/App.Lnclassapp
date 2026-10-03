# 🔌 INFRA · Repositories::Shared::RichTextSanitizer
# Rôle : assainit tout HTML écrit dans un contenu riche (liste blanche de Rails) ; sans pièce jointe, sauf les images admises d'un article
# ADR  : 0039, 0049, 0068, 0074 · UDR : 0014, 0067
module Repositories
  module Shared
    # Retire <script>, <style>, <iframe>, les attributs on*, les liens javascript: et les <action-text-attachment> :
    # les cours, les fiches et les imports n'acceptent aucune pièce jointe, et Trix n'est pas un garde-fou pour une
    # requête forgée. Seul l'adaptateur des articles passe image_ids (ADR-0074 §4.5).
    module RichTextSanitizer
      ATTACHMENT = "action-text-attachment"

      # Le filtre de Rails::HTML5::SafeListSanitizer, avec ses balises et attributs permis par défaut.
      SCRUBBER = Rails::HTML::PermitScrubber.new.tap do |scrubber|
        scrubber.tags = Rails::HTML5::SafeListSanitizer.allowed_tags
        scrubber.attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes
      end

      # html : String | nil → String | nil. Loofah élague d'abord les balises dangereuses avec leur contenu,
      # pour qu'un <script> ne laisse pas son code en texte ; la liste blanche de Rails règle ensuite les attributs.
      # Une seule analyse (ADR-0068 §4) : les deux filtres passent sur le même fragment.
      # image_ids : nil (aucune pièce jointe, comportement des cours) ou Set des id d'Orm::ArticleImage admis.
      def self.call(html, image_ids: nil)
        return html if html.nil?
        return Loofah.html5_fragment(html).scrub!(:prune).scrub!(SCRUBBER).to_s unless image_ids

        Loofah.html5_fragment(html).scrub!(ArticlePrune.new).scrub!(ArticleScrubber.new(image_ids)).to_s
      end

      # L'élagage de Loofah, qui épargne la seule balise inconnue de Loofah qu'un article garde : la pièce jointe. Son
      # contenu est élagué comme le reste, puis vidé par ArticleScrubber.
      class ArticlePrune < Loofah::Scrubbers::Prune
        def scrub(node) = node.name == ATTACHMENT ? CONTINUE : super
      end

      # Liste blanche de Rails sans <img> (une image d'article n'est qu'une pièce jointe de cet article), plus
      # <action-text-attachment> vers une image admise, avec ses seuls attributs ; h1 → h2 (un seul h1 par page).
      class ArticleScrubber < Rails::HTML::PermitScrubber
        ATTACHMENT_ATTRIBUTES = %w[sgid content-type width height caption filename filesize presentation].freeze
        IMAGE_MODEL = "Orm::ArticleImage"

        def initialize(image_ids)
          super()
          @image_ids = image_ids
          self.tags = Rails::HTML5::SafeListSanitizer.allowed_tags.to_a - %w[img] + [ ATTACHMENT ]
          self.attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes
        end

        def scrub(node)
          node.name = "h2" if node.name == "h1"
          super
        end

        protected

        # Un sgid se lit sans requête : il désigne une ligne, que l'ensemble admis connaît ou non.
        def allowed_node?(node)
          return super unless node.name == ATTACHMENT

          gid = SignedGlobalID.parse(node["sgid"].to_s, for: ActionText::Attachable::LOCATOR_NAME)
          gid&.model_name == IMAGE_MODEL && @image_ids.include?(gid.model_id.to_i)
        end

        def scrub_attributes(node)
          return super unless node.name == ATTACHMENT

          node.children.remove
          node.attribute_nodes.each { it.remove unless ATTACHMENT_ATTRIBUTES.include?(it.name) }
        end
      end
    end
  end
end
