# 🌐 DELIVERY · routes du contexte assessment
# Rôle : exercice, session, soumission d'une réponse, résultat
# ADR  : 0054 · pas de route de clôture : la dernière réponse clôt la session
get "exercises/:public_id", to: "assessment/exercises#show", as: :exercise
post "exercises/:exercise_public_id/sessions", to: "assessment/exercise_sessions#create", as: :exercise_sessions
get "sessions/:public_id", to: "assessment/exercise_sessions#show", as: :exercise_session
post "sessions/:public_id/attempts", to: "assessment/question_attempts#create", as: :exercise_session_attempts
get "sessions/:public_id/result", to: "assessment/session_results#show", as: :exercise_session_result
