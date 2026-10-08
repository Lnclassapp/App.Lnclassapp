# 🌐 DELIVERY · routes du contexte school (hors espace équipe)
# Rôle : établissements d'une DRENA pour l'inscription (HTML, JSON) ; niveaux et classes d'un établissement pour l'élève ; garant
# ADR  : 0030, 0063, 0085
get "drenas/:drena_public_id/schools", to: "school/drena_schools#index", as: :drena_schools
# ADR-0085 §4.2 : la cascade de l'inscription élève, limitée en débit ; une classe n'y montre que son nom et « complète ».
get "schools/:school_public_id/levels", to: "school/school_levels#index", as: :school_picker_levels
get "schools/:school_public_id/levels/:level_slug/classrooms", to: "school/level_classrooms#index", as: :school_picker_classrooms
# ADR-0063 : un enseignant actif se porte garant d'un collègue en attente de son établissement (« Je confirme »).
post "teachers/join-requests/:public_id/vouch", to: "school/join_request_vouches#create", as: :join_request_vouch
