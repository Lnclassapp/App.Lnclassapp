# 🔌 INFRA · Queries::Communication::ArticleSignature
# Rôle : nom de l'auteur d'un article public, NULL s'il signe « L'équipe Lnclass » ou si son compte est anonymisé
# ADR  : 0036, 0074 (§4.8)
module Queries
  module Communication
    module ArticleSignature
      # À lire après une jointure de articles sur users (l'auteur). Un futur état « désactivé » s'ajoute ici, et seulement
      # ici (BL-18). La gestion du blog (UDR-0067) lit le nom réel : elle ne passe pas par cette constante.
      AUTHOR_NAME = "CASE WHEN articles.signature = 'author' AND users.anonymized_at IS NULL " \
                    "THEN users.first_name || ' ' || users.last_name END".freeze
    end
  end
end
