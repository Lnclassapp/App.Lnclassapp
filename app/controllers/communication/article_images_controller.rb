# 🌐 DELIVERY · Communication::ArticleImagesController
# Rôle : sert une image d'article, seul chemin d'une image du blog : cache public immuable si l'article est publié, sinon privé
# ADR  : 0047, 0049, 0073 · UDR : 0064, 0065
module Communication
  class ArticleImagesController < ApplicationController
    allow_unauthenticated_access
    # Une image n'écrit jamais le cookie de session (nonce CSP compris) : une réponse publique et immuable ne doit pas
    # en porter, sans quoi un relais pourrait servir le même cookie à tous ses lecteurs.
    before_action { request.session_options[:skip] = true }

    # L'adresse est versionnée par construction : une ligne ne change jamais de fichier (ADR-0073 §4.4). Directives de
    # l'ADR, dans l'ordre où Rails les écrit.
    PUBLIC_CACHE = "max-age=31536000, public, immutable"
    # Brouillon, archivé ou image pas encore rattachée, lus par qui gère le blog : ni navigateur ni relais ne gardent l'octet.
    PRIVATE_CACHE = "private, no-store"

    def show
      render_result read.call(actor: current_actor, public_id: params[:public_id]), success: lambda { |image|
        response.headers["Cache-Control"] = image.public ? PUBLIC_CACHE : PRIVATE_CACHE
        send_data image.data, type: image.content_type, disposition: :inline, filename: "image"
      }
    end

    private

    def read
      UseCases::Communication::ReadArticleImage.new(images: Repositories::Communication::ArticleImageStore.new,
                                                    policy: Policies::Communication::ReadArticlePolicy.new)
    end
  end
end
