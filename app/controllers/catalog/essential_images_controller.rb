# 🌐 DELIVERY · Catalog::EssentialImagesController
# Rôle : sert une image de fiche, seul chemin d'une image du texte d'une fiche, sous la règle de lecture de sa fiche et du niveau de l'élève
# ADR  : 0047, 0105 · UDR : 0129
module Catalog
  class EssentialImagesController < AuthenticatedController
    include ReadsOwnLevel

    # Le catalogue est sous connexion : jamais de cache public ni de relais partagé, seulement le navigateur du lecteur.
    # Une heure, puis revalidation par ETag : la règle de lecture est rejouée, une fiche retirée ne reste pas lisible (ADR-0105 §4.5).
    PUBLISHED_CACHE = "max-age=3600, private"
    UNPUBLISHED_CACHE = "private, no-store"

    def show
      render_result read.call(actor: current_actor, public_id: params[:public_id]), success: lambda { |image|
        return if image.course_id && refuse_out_of_level(course_id: image.course_id)

        serve(image)
      }
    end

    private

    # Image lisible de tous : ETag = public_id ; un navigateur qui l'a déjà reçoit 304, après la règle de lecture, sans que le bucket soit lu.
    def serve(image)
      response.headers["Cache-Control"] = image.public ? PUBLISHED_CACHE : UNPUBLISHED_CACHE
      return if image.public && !stale?(etag: params[:public_id])

      data = image.data.call
      return missing_file if data.nil?

      send_data data, type: image.content_type, disposition: :inline, filename: "image"
    end

    # La ligne existe mais pas son fichier (donnée incohérente) : 404 plutôt qu'une image vide, et une trace pour l'exploitant.
    def missing_file
      Rails.logger.error("[Catalog::EssentialImagesController] fichier absent public_id=#{params[:public_id]}")
      # Un 404 n'est jamais gardé (ni cache public, ni ETag) : une fois le fichier restauré, l'adresse doit servir l'image.
      response.headers["Cache-Control"] = UNPUBLISHED_CACHE
      response.headers.delete("ETag")
      head :not_found
    end

    def read
      UseCases::Catalog::ReadEssentialImage.new(images: Repositories::Catalog::EssentialImageStore.new,
                                                essentials: Repositories::Catalog::EssentialRepository.new,
                                                policy: Policies::Catalog::ReadPublishedPolicy.new)
    end
  end
end
