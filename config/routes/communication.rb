# 🌐 DELIVERY · routes du contexte communication
# Rôle : annonces ; questions fréquentes (/aide), pages publiques (mission, données, CGU, CGV), blog, plan du site, sans connexion
# ADR  : 0045 · V6 · 0073 · UDR : 0061 (FAQ), 0063 (pages publiques), 0064 (blog)
get "aide", to: "communication/help#show", as: :help

# UDR-0063 §3.1 : adresses en français ; une page hors de Communication::PagesController::ONLINE répond 404.
get "mission", to: "communication/pages#mission", as: :mission
get "confidentialite", to: "communication/pages#privacy", as: :privacy
get "conditions-utilisation", to: "communication/pages#terms", as: :terms
get "conditions-vente", to: "communication/pages#sales_terms", as: :sales_terms

# ADR-0073 §6, UDR-0064 §3.1 : le blog public. Les images avant les articles : chemin fixe, jamais pris pour un slug.
get "blog", to: "communication/articles#index", as: :blog
get "blog/images/:public_id", to: "communication/article_images#show", as: :blog_image
get "blog/:slug", to: "communication/articles#show", as: :blog_article
# ADR-0073 §4.6 : plan du site et robots.txt par des routes, sur l'hôte canonique (config.x.canonical_host).
get "sitemap.xml", to: "communication/sitemaps#show", defaults: { format: :xml }, as: :sitemap
get "robots.txt", to: "communication/sitemaps#robots", defaults: { format: :text }, as: :robots
