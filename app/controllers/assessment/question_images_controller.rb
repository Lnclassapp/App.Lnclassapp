# 🌐 DELIVERY · Assessment::QuestionImagesController
# Rôle : sert l'image d'une question sous la règle de lecture de son exercice : cache navigateur privé et immuable si publiée
# ADR  : 0028, 0035, 0047, 0089 · UDR : 0084
module Assessment
  class QuestionImagesController < AuthenticatedController
    include ReadsOwnLevel

    # Le catalogue est sous connexion : une image publiée ne se garde que dans le navigateur, jamais dans un relais (ADR-0089 §4.5).
    PUBLISHED_CACHE = "max-age=31536000, private, immutable"
    PRIVATE_CACHE = "private, no-store"

    def show
      render_result read.call(actor: current_actor, public_id: params[:public_id]), success: lambda { |image|
        serve(image) unless image.exercise_public_id && refuse_out_of_level(exercise_public_id: image.exercise_public_id)
      }
    end

    private

    # Une ligne ne change jamais de fichier : ETag = public_id, et un navigateur qui a l'image reçoit 304 sans lecture du bucket.
    def serve(image)
      response.headers["Cache-Control"] = image.public ? PUBLISHED_CACHE : PRIVATE_CACHE
      return if image.public && !stale?(etag: params[:public_id])

      send_data image.data.call, type: image.content_type, disposition: :inline, filename: "image"
    end

    def read
      UseCases::Assessment::ReadQuestionImage.new(images: Repositories::Assessment::QuestionImageStore.new,
                                                  exercises: Repositories::Assessment::ExerciseRepository.new,
                                                  policy: Policies::Catalog::ReadPublishedPolicy.new)
    end
  end
end
