# 🌐 DELIVERY · routes du contexte catalog (lecture)
# Rôle : catalogue, cours et fiches essentielles, adressés par slug ; pages publiques Niveau, Série et Matière, sans compte
# ADR  : 0029, 0035, 0099 (§4.3), 0105, XXXX (fiche de cours)
get "courses", to: "catalog/courses#index", as: :courses # gelé
get "courses/:slug", to: "catalog/courses#show", as: :course
get "courses/:course_slug/essentials/:slug", to: "catalog/essentials#show", as: :course_essential
# Fiche de cours d'une leçon (contenu-en-blocs, #318) : lecture seule, 404 si la leçon n'en a pas.
get "courses/:course_slug/fiche", to: "catalog/course_sheets#show", as: :course_sheet
# ADR-0105 §4.5 : une image de fiche, sous la règle de lecture de sa fiche.
get "images/fiches/:public_id", to: "catalog/essential_images#show", as: :essential_image

# ADR-0099 §4.3 : adresses françaises, à slug figé (ADR-0029, ADR-0034), lisibles sans compte.
get "niveaux", to: "catalog/level_pages#index", as: :public_levels
get "niveaux/:slug", to: "catalog/level_pages#show", as: :public_level
get "niveaux/:level_slug/:series_slug", to: "catalog/series_pages#show", as: :public_level_series
get "matieres/:slug", to: "catalog/material_pages#show", as: :public_material
