# 🧠 DOMAINE · Policies::Communication::ReadArticlePolicy
# Rôle : publié → tous ; qui gère → tout état ; archivé → :expired (410) ; brouillon → :not_found (introuvable)
# ADR  : 0028, 0035, 0074
module Policies
  module Communication
    class ReadArticlePolicy
      # article : tout objet qui répond à status (la Detail de la query de lecture, une entité).
      def call(actor:, article:)
        return Shared::Result.success if article.status == "published"
        return Shared::Result.success if ManageArticlesPolicy.new.call(actor:).success?

        Shared::Result.failure(article.status == "archived" ? :expired : :not_found)
      end
    end
  end
end
