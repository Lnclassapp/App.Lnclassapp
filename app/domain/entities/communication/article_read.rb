# 🧠 DOMAINE · Entities::Communication::ArticleRead
# Rôle : dit si l'ouverture d'un article est une lecture : ni robot qui se déclare, ni préchargement, ni aperçu
# ADR  : 0049, 0074
module Entities
  module Communication
    module ArticleRead
      # Un agent vide, ou qui se déclare robot (l'aperçu de WhatsApp et de Facebook compris). « bot » compte suivi d'un
      # séparateur (Googlebot/2.1, AdsBot-Google, bingbot;) ou seul, jamais dans un nom de modèle : un téléphone CUBOT X30
      # est un lecteur.
      ROBOTS = %r{bot(?:[/\-;)]|\z)|\bbot\b|crawl|spider|slurp|facebookexternalhit|whatsapp|preview|curl|wget|python|headless}i
      # Turbo 8 précharge un lien au survol ; les navigateurs l'annoncent par l'un de ces en-têtes. Safari annonce
      # l'aperçu d'une page (Top Sites, aperçu de lien) par « X-Purpose: preview ».
      PURPOSE_HEADERS = %w[Sec-Purpose X-Sec-Purpose Purpose X-Purpose].freeze
      PREFETCH = /prefetch|preview/i

      # user_agent : String | nil. headers : les en-têtes de la requête, lus par leur nom (PURPOSE_HEADERS). → Boolean
      def self.countable?(user_agent:, headers:)
        return false if user_agent.to_s.strip.empty? || user_agent.match?(ROBOTS)

        PURPOSE_HEADERS.none? { headers[it].to_s.match?(PREFETCH) }
      end
    end
  end
end
