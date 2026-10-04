# 🌐 DELIVERY · routes du contexte communication
# Rôle : annonces (comptes connectés, sans page de détail) ; FAQ (/aide), pages publiques, blog, plan du site, sans connexion
# ADR  : 0045, 0074, 0078 · UDR : 0061 (FAQ), 0063 (pages publiques), 0066 (blog), 0071 (annonces)
get "aide", to: "communication/help#show", as: :help

# UDR-0063 §3.1 : adresses en français ; une page hors de Communication::PagesController::ONLINE répond 404.
get "mission", to: "communication/pages#mission", as: :mission
get "confidentialite", to: "communication/pages#privacy", as: :privacy
get "conditions-utilisation", to: "communication/pages#terms", as: :terms
get "conditions-vente", to: "communication/pages#sales_terms", as: :sales_terms

# ADR-0074 §6, UDR-0066 §3.1 : le blog public. Les images avant les articles : chemin fixe, jamais pris pour un slug.
get "blog", to: "communication/articles#index", as: :blog
get "blog/images/:public_id", to: "communication/article_images#show", as: :blog_image
get "blog/:slug", to: "communication/articles#show", as: :blog_article
# ADR-0074 §4.6 : plan du site et robots.txt par des routes, sur l'hôte canonique (config.x.canonical_host).
get "sitemap.xml", to: "communication/sitemaps#show", defaults: { format: :xml }, as: :sitemap
get "robots.txt", to: "communication/sitemaps#robots", defaults: { format: :text }, as: :robots

# ADR-0078, UDR-0071 : les annonces, pour les comptes connectés ; une annonce par son public_id, sans page de détail.
scope module: "communication" do
  get "announcements", to: "inboxes#show", as: :announcements
  get "announcements/mine", to: "authored_messages#index", as: :my_announcements
  get "announcements/moderation", to: "moderations#index", as: :moderated_announcements
  get "announcements/new", to: "authored_messages#new", as: :new_announcement
  post "announcements", to: "authored_messages#create"
  get "announcements/:public_id/edit", to: "authored_messages#edit", as: :edit_announcement
  patch "announcements/:public_id", to: "authored_messages#update", as: :announcement
  post "announcements/:public_id/archive", to: "message_archives#create", as: :announcement_archive
  post "announcements/:public_id/withdrawal", to: "message_withdrawals#create", as: :announcement_withdrawal
  post "announcements/:public_id/dismissal", to: "message_dismissals#create", as: :announcement_dismissal
  delete "announcements/:public_id/dismissal", to: "message_dismissals#destroy"
  get "announcements/:public_id/:kind", to: "message_files#show", as: :announcement_file, constraints: { kind: /image|audio/ }
end
