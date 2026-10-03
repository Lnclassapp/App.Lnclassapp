# 🌐 DELIVERY · Communication::SitemapsController — /sitemap.xml et /robots.txt, servis par des routes
# Rôle : plan du site (accueil, /aide, pages en ligne, /blog, articles publiés) et robots.txt sur l'hôte canonique, cache court
# ADR  : 0074 (§4.6 : public/robots.txt supprimé, public/ est en cache d'un an) · PRD blog : BL-05, BL-19
module Communication
  class SitemapsController < ApplicationController
    allow_unauthenticated_access

    # Une réponse en cache public ne pose aucun cookie : le nonce CSP ne doit pas ouvrir de session Rails ici.
    before_action { request.session_options[:skip] = true }

    def show
      expires_in 1.hour, public: true
      @articles = Queries::Communication::SitemapQuery.new.call
    end

    def robots
      expires_in 1.day, public: true
    end
  end
end
