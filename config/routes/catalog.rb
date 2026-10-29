# 🌐 DELIVERY · routes du contexte catalog (lecture)
# Rôle : catalogue, cours et fiches essentielles, adressés par slug ; pages publiques Niveau, Série et Matière, sans compte
# ADR  : 0029, 0035, 0099 (§4.3), 0110 (fiche de cours), XXXX
get "courses", to: "catalog/courses#index", as: :courses # gelé
get "courses/:slug", to: "catalog/courses#show", as: :course
get "courses/:course_slug/essentials/:slug", to: "catalog/essentials#show", as: :course_essential
# Ancienne adresse de la fiche de cours : 301 vers la fiche de révision de la page de la leçon (CA-12, ADR-XXXX §4.5).
get "courses/:course_slug/fiche", to: "catalog/courses#fiche", as: :course_fiche

# ADR-0099 §4.3 : adresses françaises, à slug figé (ADR-0029, ADR-0034), lisibles sans compte.
get "niveaux", to: "catalog/level_pages#index", as: :public_levels
get "niveaux/:slug", to: "catalog/level_pages#show", as: :public_level
get "niveaux/:level_slug/:series_slug", to: "catalog/series_pages#show", as: :public_level_series
get "matieres/:slug", to: "catalog/material_pages#show", as: :public_material
