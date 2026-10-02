# 🌐 DELIVERY · Teams::ArticleImagesController
# Rôle : l'éditeur du blog envoie une image d'article ; 201 { public_id, sgid, url, width, height }, 422 { error }, 403 en JSON
# ADR  : 0026, 0028, 0060, 0073 · UDR : 0065
module Teams
  class ArticleImagesController < BaseController
    # Paramètre article : l'article en cours de modification ; absent à la création (UDR-0065 §3.0).
    def create
      result = upload.call(actor: current_actor, dto: Dtos::Communication::ArticleImageInput.new(file: uploaded_file),
                           article_public_id: params[:article].to_s.presence)
      # La raison est déjà rédigée en français par le serveur : l'éditeur l'affiche telle quelle (UDR-0065 §3.4.3).
      return render(json: { error: result.errors.values.flatten.first }, status: :unprocessable_entity) if result.code == :invalid

      render_result result, success: lambda { |image|
        render json: { public_id: image.public_id, sgid: image.sgid, url: blog_image_path(image.public_id),
                       width: image.width, height: image.height }, status: :created
      }
    end

    private

    # Seul un vrai fichier téléversé compte ; une chaîne dans le paramètre vaut une absence de fichier.
    def uploaded_file
      file = params.dig(:article_image, :file)
      file if file.is_a?(ActionDispatch::Http::UploadedFile)
    end

    def upload
      UseCases::Communication::UploadArticleImage.new(images: Repositories::Communication::ArticleImageStore.new,
                                                      articles: Repositories::Communication::ArticleRepository.new,
                                                      policy: Policies::Communication::ManageArticlesPolicy.new)
    end
  end
end
