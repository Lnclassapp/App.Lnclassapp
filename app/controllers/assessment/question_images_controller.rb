# 🌐 DELIVERY · Assessment::QuestionImagesController
# Rôle : sert l'image d'une question sous la règle de lecture de son exercice : cache navigateur privé d'une heure si publiée
# ADR  : 0028, 0035, 0047, 0104 · UDR : 0129
module Assessment
  class QuestionImagesController < AuthenticatedController
    include ReadsOwnLevel

    # Le catalogue est sous connexion : une image publiée ne se garde qu'une heure dans le navigateur, jamais dans un relais ;
    # passé ce délai, la revalidation rejoue la règle de lecture (ADR-0104 §4.5).
    PUBLISHED_CACHE = "max-age=3600, private"
    PRIVATE_CACHE = "private, no-store"

    def show
      render_result read.call(actor: current_actor, public_id: params[:public_id]), success: lambda { |image|
        serve(image) unless image.exercise_public_id && refuse_out_of_level(exercise_public_id: image.exercise_public_id)
      }
    end

    private

    # Une ligne ne change jamais de fichier : ETag = public_id, et un navigateur qui a l'image reçoit 304, après la règle de lecture, sans lecture du bucket.
    def serve(image)
      response.headers["Cache-Control"] = image.public ? PUBLISHED_CACHE : PRIVATE_CACHE
      return if image.public && !stale?(etag: params[:public_id])

      data = image.data.call
      return missing_file if data.nil?

      send_data data, type: image.content_type, disposition: :inline, filename: "image"
    end

    # La ligne existe mais pas son fichier (donnée incohérente) : 404 plutôt qu'une image vide, et une trace pour l'exploitant.
    def missing_file
      Rails.logger.error("[Assessment::QuestionImagesController] fichier absent public_id=#{params[:public_id]}")
      head :not_found
    end

    def read
      UseCases::Assessment::ReadQuestionImage.new(images: Repositories::Assessment::QuestionImageStore.new,
                                                  exercises: Repositories::Assessment::ExerciseRepository.new,
                                                  policy: Policies::Catalog::ReadPublishedPolicy.new)
    end
  end
end
