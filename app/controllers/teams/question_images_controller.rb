# 🌐 DELIVERY · Teams::QuestionImagesController
# Rôle : le formulaire d'exercice envoie l'image d'une question ; 201 { public_id, url, width, height }, 422 { error }, 403 et 401 en JSON
# ADR  : 0026, 0028, 0049, 0060, 0104 · UDR : 0129
module Teams
  class QuestionImagesController < BaseController
    # ADR-0049 : un compte de l'équipe n'envoie pas plus de 60 images par minute ; les non rattachées attendent la purge.
    rate_limit to: 60, within: 1.minute, only: :create, by: -> { current_actor.user_id },
               with: -> { render json: { error: t("errors.codes.rate_limited") }, status: :too_many_requests }

    def create
      result = upload.call(actor: current_actor, dto: Dtos::Shared::ContentImageInput.new(file: uploaded_file))
      # La raison est déjà rédigée en français par le serveur : le formulaire l'affiche telle quelle (UDR-0129 §3.2).
      return render(json: { error: result.errors.values.flatten.first }, status: :unprocessable_entity) if result.code == :invalid

      render_result result, success: lambda { |image|
        render json: { public_id: image.public_id, url: question_image_path(image.public_id), width: image.width, height: image.height },
               status: :created
      }
    end

    private

    # Session expirée pendant la saisie : l'envoi (JSON) reçoit 401 { error }, comme l'éditeur du blog (UDR-0067 §3.4.3).
    def require_authentication
      return super if authenticated? || !request.format.json?

      render json: { error: "unauthenticated" }, status: :unauthorized
    end

    # Seul un vrai fichier téléversé compte ; une chaîne, à la place du fichier ou de question_image, vaut une absence.
    def uploaded_file
      image = params[:question_image]
      file = image[:file] if image.is_a?(ActionController::Parameters)
      file if file.is_a?(ActionDispatch::Http::UploadedFile)
    end

    def upload
      UseCases::Assessment::UploadQuestionImage.new(images: Repositories::Assessment::QuestionImageStore.new,
                                                    policy: Policies::Catalog::ManageContentPolicy.new)
    end
  end
end
