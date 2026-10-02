# 🧠 DOMAINE · Entities::Communication::ArticleRead
# Rôle : dit si l'ouverture d'un article est une lecture : ni robot qui se déclare, ni préchargement
# ADR  : 0049, 0073
module Entities
  module Communication
    module ArticleRead
      # Un agent vide, ou qui se déclare robot (l'aperçu de WhatsApp et de Facebook compris).
      ROBOTS = /bot|crawl|spider|slurp|facebookexternalhit|whatsapp|preview|curl|wget|python|headless/i
      # Turbo 8 précharge un lien au survol ; les navigateurs l'annoncent par l'un de ces en-têtes.
      PURPOSE_HEADERS = %w[Sec-Purpose X-Sec-Purpose Purpose].freeze
      PREFETCH = /prefetch/i

      # user_agent : String | nil. headers : les en-têtes de la requête, lus par leur nom (PURPOSE_HEADERS). → Boolean
      def self.countable?(user_agent:, headers:)
        return false if user_agent.to_s.strip.empty? || user_agent.match?(ROBOTS)

        PURPOSE_HEADERS.none? { headers[it].to_s.match?(PREFETCH) }
      end
    end
  end
end
