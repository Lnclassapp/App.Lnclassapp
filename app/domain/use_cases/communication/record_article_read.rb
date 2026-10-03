# 🧠 DOMAINE · UseCases::Communication::RecordArticleRead
# Rôle : compte la lecture d'un article publié, ni par l'équipe, ni par un robot, ni par un préchargement ; ne lève jamais
# ADR  : 0026, 0028, 0049, 0073 (§4.7)
module UseCases
  module Communication
    class RecordArticleRead
      # reporter : répond à report(error, handled: true) (Rails.error, injecté par le contrôleur).
      def initialize(articles:, policy:, reporter:)
        @articles = articles
        @policy = policy
        @reporter = reporter
      end

      # article : tout objet qui répond à id et status (la Detail de la query de lecture). headers : en-têtes lus par leur
      # nom. → Result(true : lecture comptée | false : non comptée) | :not_found (brouillon) | :expired (archivé)
      def call(actor:, article:, user_agent:, headers:)
        allowed = @policy.call(actor:, article:)
        return allowed if allowed.failure?
        # L'aperçu de l'équipe (brouillon, archivé) et toute lecture par l'équipe ne comptent pas.
        return Shared::Result.success(false) if article.status != "published" || actor&.team?
        return Shared::Result.success(false) unless Entities::Communication::ArticleRead.countable?(user_agent:, headers:)

        Shared::Result.success(@articles.increment_reads(article_id: article.id))
      rescue StandardError => error
        # Le compteur ne bloque jamais la page (ADR-0073 §4.7) : l'erreur est signalée, la lecture n'est pas comptée.
        @reporter.report(error, handled: true)
        Shared::Result.success(false)
      end
    end
  end
end
