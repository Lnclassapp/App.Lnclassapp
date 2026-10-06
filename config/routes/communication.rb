# 🌐 DELIVERY · routes du contexte communication
# Rôle : annonces ; questions fréquentes (/aide) et pages publiques (mission, données, CGU, CGV), sans connexion
# ADR  : 0045 · V6 · UDR : 0061 (FAQ), 0063 (pages publiques)
get "aide", to: "communication/help#show", as: :help

# UDR-0063 §3.1 : adresses en français ; une page hors de Communication::PagesController::ONLINE répond 404.
get "mission", to: "communication/pages#mission", as: :mission
get "confidentialite", to: "communication/pages#privacy", as: :privacy
get "conditions-utilisation", to: "communication/pages#terms", as: :terms
get "conditions-vente", to: "communication/pages#sales_terms", as: :sales_terms
