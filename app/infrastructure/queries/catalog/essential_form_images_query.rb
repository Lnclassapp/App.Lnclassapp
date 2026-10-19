# 🔌 INFRA · Queries::Catalog::EssentialFormImagesQuery
# Rôle : images du texte d'une fiche pour la modale (ordre du texte, sgid, adresse, texte de remplacement)
# ADR  : 0104 · UDR : 0129
module Queries
  module Catalog
    class EssentialFormImagesQuery
      # Ce que lit teams/articles/_image_alt_row, partagé avec le blog.
      Row = Data.define(:public_id, :sgid, :url, :alt)
      IMAGE_MODEL = "Orm::EssentialImage"

      # content : le HTML enregistré, ou celui que Trix envoie (figures) ; image_alts : la saisie, { public_id => alt }.
      # Seules les images de la fiche, ou à personne encore, sont montrées : l'assainisseur retirerait les autres.
      # → Array<Row>, dans l'ordre du texte ; un texte de remplacement absent de la saisie garde sa valeur enregistrée.
      def call(content:, image_alts: {}, essential_slug: nil)
        ids = cited_ids(content)
        return [] if ids.empty?

        images = admissible(essential_slug).where(id: ids).index_by(&:id)
        ids.filter_map { images[it] }.map do |image|
          alt = image_alts.key?(image.public_id) ? image_alts[image.public_id] : image.alt
          Row.new(public_id: image.public_id, sgid: image.attachable_sgid, alt:,
                  url: Rails.application.routes.url_helpers.essential_image_path(image.public_id))
        end
      end

      private

      def admissible(essential_slug)
        scope = Orm::EssentialImage.left_joins(:essential)
        scope.where(essential_id: nil).or(scope.where(essentials: { slug: essential_slug }))
      end

      # Le texte est d'abord canonisé (figures de Trix → pièces jointes) ; les sgid se lisent sans requête.
      def cited_ids(content)
        html = ActionText::Content.new(content.to_s).to_html
        Nokogiri::HTML5.fragment(html).css(ActionText::Attachment.tag_name).filter_map do |node|
          gid = SignedGlobalID.parse(node["sgid"].to_s, for: ActionText::Attachable::LOCATOR_NAME)
          gid.model_id.to_i if gid&.model_name == IMAGE_MODEL
        end.uniq
      end
    end
  end
end
