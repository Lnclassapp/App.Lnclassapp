# 🌐 DELIVERY · Communication::SitemapsController — /sitemap.xml et /robots.txt, servis par des routes
# Rôle : plan du site (accueil, /aide, pages en ligne, /blog, articles publiés, catalogue public) et robots.txt sur l'hôte canonique, cache court
# ADR  : 0074 (§4.6 ; amendement du 2026-10-07 : seule la production s'indexe), 0099 (§4.4) · PRD blog : BL-05, BL-19 · PRD catalogue : CC-21
module Communication
  class SitemapsController < ApplicationController
    allow_unauthenticated_access

    # Une réponse en cache public ne pose aucun cookie : le nonce CSP ne doit pas ouvrir de session Rails ici.
    before_action { request.session_options[:skip] = true }

    def show
      expires_in 1.hour, public: true
      @articles = Queries::Communication::SitemapQuery.new.call
      @catalog = Queries::Catalog::PublicSitemapQuery.new.call
    end

    # ADR-0074, amendement du 2026-10-07 : l'hôte de la requête décide, jamais une variable. Hors production, tout robot
    # est refusé et aucun plan du site n'est annoncé.
    def robots
      expires_in 1.day, public: true
      @indexed = Rails.configuration.x.indexed_hosts.include?(request.host)
    end
  end
end
