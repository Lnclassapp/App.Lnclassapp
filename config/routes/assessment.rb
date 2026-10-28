# 🌐 DELIVERY · routes du contexte assessment
# Rôle : exercice, session, soumission d'une réponse, résultat
# ADR  : 0054, 0105, 0112 · pas de route de clôture : la dernière réponse clôt la session
get "exercises/:public_id", to: "assessment/exercises#show", as: :exercise
post "exercises/:exercise_public_id/sessions", to: "assessment/exercise_sessions#create", as: :exercise_sessions
get "sessions/:public_id", to: "assessment/exercise_sessions#show", as: :exercise_session
post "sessions/:public_id/attempts", to: "assessment/question_attempts#create", as: :exercise_session_attempts
# ADR-XXXX copie à rendre §4.3 : la copie entière en un envoi (le contrôleur arrive au Lot C ; l'envoi par question reste jusqu'au Lot E).
post "sessions/:public_id/copy", to: "assessment/exercise_copies#create", as: :exercise_session_copy
get "sessions/:public_id/result", to: "assessment/session_results#show", as: :exercise_session_result
# ADR-0105 §4.5 : l'image d'une question, sous la règle de lecture de son exercice.
get "images/questions/:public_id", to: "assessment/question_images#show", as: :question_image
