# 🌐 DELIVERY · Communication::ArticlesController — blog public : liste /blog et page d'un article, sans shell
# Rôle : lit les queries, applique ReadArticlePolicy (404 brouillon, 410 archivé, jamais render_result), compte la lecture
# ADR  : 0049, 0073 (§4.2, §4.7, §4.8) · UDR : 0064 (§3.1)
module Communication
  class ArticlesController < ApplicationController
    allow_unauthenticated_access

    # params[:page] : entier de 1 à 999 999 ; absent ou invalide, la première page.
    PAGE = /\A[1-9]\d{0,5}\z/

    def index
      page = params[:page].to_s[PAGE]&.to_i || 1
      @page = Queries::Communication::PublishedArticlesQuery.new.call(page:)
      # Pas de page vide indexable (UDR-0064 §3.1).
      render_not_found if @page.page > @page.pages
    end

    # RendersResult traduirait :expired en renvoi vers la connexion : l'archivé est rendu ici, en 410 (ADR-0073 §4.2).
    def show
      @article = Queries::Communication::ArticleDetailQuery.new.call(slug: params[:slug]) or return render_not_found
      read = Policies::Communication::ReadArticlePolicy.new.call(actor: current_actor, article: @article)
      return render(:gone, status: :gone) if read.code == :expired
      return render_not_found if read.failure?

      record_read if request.get? && request.format.html?
    end

    private

    # Le rendu ne dépend pas du compteur, et un échec du compteur ne bloque jamais la page (ADR-0073 §4.7).
    def record_read
      UseCases::Communication::RecordArticleRead.new(
        articles: Repositories::Communication::ArticleRepository.new, policy: Policies::Communication::ReadArticlePolicy.new,
        reporter: Rails.error
      ).call(actor: current_actor, article: @article, user_agent: request.user_agent, headers: request.headers)
    end
  end
end
