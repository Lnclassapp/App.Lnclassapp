# 🌐 DELIVERY · Teams::ArticlesController
# Rôle : l'équipe admin et content gère le blog : liste, rédaction en modale, publication, archivage, remise en ligne (menu ⋮)
# ADR  : 0026, 0028, 0035, 0073 · UDR : 0006, 0042, 0065
module Teams
  class ArticlesController < BaseController
    FIELDS = [ :title, :excerpt, :body, :signature, :cover_public_id, :cover_alt, { image_alts: {} } ].freeze

    # Le Terrain est de l'équipe : BaseController le laisse passer, la policy du blog l'arrête (403, BL-08).
    before_action :authorize_management

    def index
      @page = team_articles.call(page: params[:page])
    end

    def new
      @form = Dtos::Communication::ArticleInput.new
    end

    # Succès : toast, modale vidée, liste re-demandée et fusionnée par morphing (le brouillon arrive en tête).
    def create
      @form = form_input
      render_result create_article.call(actor: current_actor, dto: @form), form: :new,
                                                                            success: ->(article) { respond_written(article, t(".created", title: article.title)) }
    end

    def edit
      @article = team_articles.find(public_id: params[:public_id])
      return render_not_found if @article.nil?

      @form = saved_form(@article.public_id)
    end

    def update
      @article = team_articles.find(public_id: params[:public_id])
      return render_not_found if @article.nil?

      @form = form_input(article_public_id: @article.public_id)
      result = update_article.call(actor: current_actor, public_id: @article.public_id, dto: @form)
      render_result result, form: :edit, success: lambda { |article|
        respond_written(article, t(article.published? ? ".updated_live" : ".updated", title: article.title))
      }
    end

    # Publier ou remettre en ligne. Un article incomplet rouvre la modale de modification en 422 (UDR-0065 §3.5).
    def publish
      before = team_articles.find(public_id: params[:public_id])
      result = publish_article.call(actor: current_actor, public_id: params[:public_id])
      return respond_publish_refused(result) if result.code == :invalid

      transition(result, before&.status == "archived" ? "republished" : "published")
    end

    def archive = transition(archive_article.call(actor: current_actor, public_id: params[:public_id]), "archived")

    private

    def authorize_management
      render_forbidden if policy.call(actor: current_actor).failure?
    end

    def respond_written(article, notice)
      @article = article
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to teams_articles_path, notice:, status: :see_other }
      end
    end

    # Succès : toast et ligne remplacée par morphing ; :conflict (déjà fait ou interdit) : 422, ligne relue.
    def transition(result, outcome)
      return respond_conflict if result.code == :conflict

      render_result result, success: lambda { |article|
        @article = team_articles.find(public_id: article.public_id)
        @outcome = outcome
        respond_to do |format|
          format.turbo_stream { render :transition }
          format.html { redirect_to teams_articles_path, notice: t("teams.articles.transition.#{outcome}", title: article.title), status: :see_other }
        end
      }
    end

    def respond_conflict
      @article = team_articles.find(public_id: params[:public_id])
      @outcome = "conflict"
      respond_to do |format|
        format.turbo_stream { render :transition, status: :unprocessable_entity }
        format.html { redirect_to teams_articles_path, alert: t("teams.articles.transition.conflict", title: @article.title), status: :see_other }
      end
    end

    # La modale est reconstruite depuis l'article enregistré, chaque manque sous son champ ; pas de toast.
    def respond_publish_refused(result)
      @article = team_articles.find(public_id: params[:public_id])
      @form = saved_form(@article.public_id)
      add_errors(result)
      respond_to do |format|
        format.turbo_stream { render :publish_refused, status: :unprocessable_entity }
        format.html { redirect_to edit_teams_article_path(@article.public_id), alert: t(".refused_fallback"), status: :see_other }
      end
    end

    def saved_form(public_id)
      article = articles.find_by_public_id(public_id:)
      cover_public_id = article.cover&.public_id
      Dtos::Communication::ArticleInput.new(
        title: article.title, excerpt: article.excerpt, body: article.body, signature: article.signature, cover_public_id:,
        cover_alt: article.cover_alt, cover_url: form_images.cover_url(public_id: cover_public_id, article_public_id: public_id),
        images: form_images.call(body: article.body, article_public_id: public_id)
      )
    end

    # La saisie, avec les images du texte reconstruites depuis le texte envoyé et image_alts (UDR-0065 §3.0).
    def form_input(article_public_id: nil)
      Dtos::Communication::ArticleInput.new(params.expect(article: FIELDS).to_h.symbolize_keys).tap do |form|
        form.images = form_images.call(body: form.body, image_alts: form.image_alts, article_public_id:)
        form.cover_url = form_images.cover_url(public_id: form.cover_public_id, article_public_id:)
      end
    end

    def team_articles = Queries::Communication::TeamArticlesQuery.new
    def form_images = Queries::Communication::ArticleFormImagesQuery.new
    def articles = @articles ||= Repositories::Communication::ArticleRepository.new
    def policy = Policies::Communication::ManageArticlesPolicy.new

    def create_article = UseCases::Communication::CreateArticle.new(**dependencies)
    def update_article = UseCases::Communication::UpdateArticle.new(**dependencies)
    def publish_article = UseCases::Communication::PublishArticle.new(**dependencies)
    def archive_article = UseCases::Communication::ArchiveArticle.new(**dependencies)

    def dependencies
      { articles:, audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy:, clock: Time.zone }
    end
  end
end
