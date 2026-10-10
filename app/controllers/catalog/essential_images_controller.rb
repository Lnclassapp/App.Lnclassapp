# 🌐 DELIVERY · Catalog::EssentialImagesController
# Rôle : sert une image de fiche, seul chemin d'une image du texte d'une fiche, sous la règle de lecture de sa fiche et du niveau de l'élève
# ADR  : 0047, 0089 · UDR : 0084
module Catalog
  class EssentialImagesController < AuthenticatedController
    include ReadsOwnLevel

    # Le catalogue est sous connexion : jamais de cache public ni de relais partagé, seulement le navigateur du lecteur.
    # Une ligne ne change jamais de fichier : l'adresse est versionnée par construction (ADR-0089 §4.5).
    PUBLISHED_CACHE = "max-age=31536000, private, immutable"
    UNPUBLISHED_CACHE = "private, no-store"

    def show
      render_result read.call(actor: current_actor, public_id: params[:public_id]), success: lambda { |image|
        return if image.course_id && refuse_out_of_level(course_id: image.course_id)

        serve(image)
      }
    end

    private

    # Image lisible de tous : ETag = public_id ; un navigateur qui l'a déjà reçoit 304 sans que le bucket soit lu.
    def serve(image)
      response.headers["Cache-Control"] = image.public ? PUBLISHED_CACHE : UNPUBLISHED_CACHE
      return if image.public && !stale?(etag: params[:public_id])

      send_data image.data.call, type: image.content_type, disposition: :inline, filename: "image"
    end

    def read
      UseCases::Catalog::ReadEssentialImage.new(images: Repositories::Catalog::EssentialImageStore.new,
                                                essentials: Repositories::Catalog::EssentialRepository.new,
                                                policy: Policies::Catalog::ReadPublishedPolicy.new)
    end
  end
end
