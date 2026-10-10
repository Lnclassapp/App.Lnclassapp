# 🌐 DELIVERY · Teams::EssentialImagesController
# Rôle : l'éditeur de fiche envoie une image ; 201 { public_id, sgid, url, width, height }, 422 { error }, 403 et 401 en JSON
# ADR  : 0026, 0028, 0060, 0089 · UDR : 0084
module Teams
  class EssentialImagesController < BaseController
    # Paramètre essential : le slug de la fiche en cours de modification ; absent à la création (UDR-0084 §3.0).
    def create
      result = upload.call(actor: current_actor, dto: Dtos::Shared::ContentImageInput.new(file: uploaded_file),
                           essential_slug: params[:essential].to_s.presence)
      # La raison est déjà rédigée en français par le serveur : l'éditeur l'affiche telle quelle.
      return render(json: { error: result.errors.values.flatten.first }, status: :unprocessable_entity) if result.code == :invalid

      render_result result, success: lambda { |image|
        render json: { public_id: image.public_id, sgid: image.sgid, url: essential_image_path(image.public_id),
                       width: image.width, height: image.height }, status: :created
      }
    end

    private

    # Session expirée pendant la rédaction : 401 { error } en JSON, que l'éditeur traduit en « session expirée ».
    def require_authentication
      return super if authenticated? || !request.format.json?

      render json: { error: "unauthenticated" }, status: :unauthorized
    end

    # Seul un vrai fichier téléversé compte ; une chaîne, à la place du fichier ou de essential_image, vaut une absence.
    def uploaded_file
      image = params[:essential_image]
      file = image[:file] if image.is_a?(ActionController::Parameters)
      file if file.is_a?(ActionDispatch::Http::UploadedFile)
    end

    def upload
      UseCases::Catalog::UploadEssentialImage.new(images: Repositories::Catalog::EssentialImageStore.new,
                                                  essentials: Repositories::Catalog::EssentialRepository.new,
                                                  policy: Policies::Catalog::ManageContentImagesPolicy.new)
    end
  end
end
