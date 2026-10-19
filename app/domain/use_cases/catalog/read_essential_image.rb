# 🧠 DOMAINE · UseCases::Catalog::ReadEssentialImage
# Rôle : lire les octets d'une image de fiche sous la règle de lecture de sa fiche ; gardée par le navigateur si la fiche est lisible de tous
# ADR  : 0026, 0028, 0035, 0105 · UDR : 0129
module UseCases
  module Catalog
    class ReadEssentialImage
      # public : fiche et cours publiés (cache navigateur privé et immuable) ; course_id : pour la règle de niveau de l'élève,
      # tenue par le contrôleur comme pour la fiche (ReadsOwnLevel) ; nil pour une image pas encore rattachée.
      # data : lit les octets à l'appel, et seulement alors.
      Image = Data.define(:content_type, :public, :course_id, :data)

      def initialize(images:, essentials:, policy:, manage_policy: Policies::Catalog::ManageContentImagesPolicy.new)
        @images = images
        @essentials = essentials
        @policy = policy
        @manage_policy = manage_policy
      end

      # → Result(Image) | :not_found (image inconnue ; illisible pour l'acteur, comme sa fiche) | :forbidden (sans acteur)
      def call(actor:, public_id:)
        image = @images.find(public_id:)
        return Shared::Result.failure(:not_found) if image.nil?
        return orphan(actor, image, public_id) if image.essential_slug.nil?

        essential = @essentials.find_by_slug(slug: image.essential_slug)
        return Shared::Result.failure(:not_found) if essential.nil?

        allowed = @policy.call(actor:, content: essential)
        return Shared::Result.failure(:not_found) if allowed.failure?

        success(image, public_id, public: essential.readable_chain_published?, course_id: essential.course_id)
      end

      private

      # Entre l'envoi et l'enregistrement de la fiche : seul qui gère les images la voit (aperçu de l'éditeur).
      def orphan(actor, image, public_id)
        return Shared::Result.failure(:not_found) if @manage_policy.call(actor:).failure?

        success(image, public_id, public: false, course_id: nil)
      end

      def success(image, public_id, public:, course_id:)
        Shared::Result.success(Image.new(content_type: image.content_type, public:, course_id:,
                                         data: -> { @images.download(public_id:) }))
      end
    end
  end
end
