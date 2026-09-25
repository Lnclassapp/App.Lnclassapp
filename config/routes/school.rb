# 🌐 DELIVERY · routes du contexte school (hors espace équipe)
# Rôle : établissements d'une DRENA pour l'inscription enseignant, en HTML (frame) et en JSON
# ADR  : 0030
get "drenas/:drena_public_id/schools", to: "school/drena_schools#index", as: :drena_schools
