# 🌐 DELIVERY · routes du contexte school (hors espace équipe)
# Rôle : liste des établissements d'une DRENA pour l'inscription enseignant (JSON)
# ADR  : 0030
get "api/v1/drenas/:drena_public_id/schools", to: "school/api/schools#index",
                                               as: :api_v1_drena_schools, defaults: { format: :json }
