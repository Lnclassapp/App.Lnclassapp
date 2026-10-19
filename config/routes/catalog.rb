# 🌐 DELIVERY · routes du contexte catalog (lecture)
# Rôle : catalogue, cours et fiches essentielles, adressés par slug
# ADR  : 0029, 0035, 0105
get "courses", to: "catalog/courses#index", as: :courses # gelé
get "courses/:slug", to: "catalog/courses#show", as: :course
get "courses/:course_slug/essentials/:slug", to: "catalog/essentials#show", as: :course_essential
# ADR-0105 §4.5 : une image de fiche, sous la règle de lecture de sa fiche.
get "images/fiches/:public_id", to: "catalog/essential_images#show", as: :essential_image
