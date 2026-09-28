# 🌐 DELIVERY · routes du contexte school (hors espace équipe)
# Rôle : établissements d'une DRENA pour l'inscription enseignant (HTML, JSON) ; garant d'un collègue en attente
# ADR  : 0030, 0063
get "drenas/:drena_public_id/schools", to: "school/drena_schools#index", as: :drena_schools
# ADR-0063 : un enseignant actif se porte garant d'un collègue en attente de son établissement (« Je confirme »).
post "teachers/join-requests/:public_id/vouch", to: "school/join_request_vouches#create", as: :join_request_vouch
