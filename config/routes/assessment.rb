# 🌐 DELIVERY · routes du contexte assessment
# Rôle : exercice, session, copie rendue, résultat
# ADR  : 0054, 0105, 0112, 0120-questions-a-plusieurs-cases-et-indice, 0121, hors-connexion · pas de route de clôture : le rendu de la copie clôt la session
get "exercises/:public_id", to: "assessment/exercises#show", as: :exercise
post "exercises/:exercise_public_id/sessions", to: "assessment/exercise_sessions#create", as: :exercise_sessions
# ADR-0121 §4 : « Vérifier ma réponse » de la feuille de la leçon, une copie rendue en un envoi (Turbo Stream).
post "exercises/:exercise_public_id/sheet_check", to: "assessment/sheet_checks#create", as: :exercise_sheet_check
get "sessions/:public_id", to: "assessment/exercise_sessions#show", as: :exercise_session
# ADR-XXXX copie à rendre §4.3 : la copie entière en un envoi ; plus d'envoi par question (ADR-0113, CA-23).
post "sessions/:public_id/copy", to: "assessment/exercise_copies#create", as: :exercise_session_copy
get "sessions/:public_id/result", to: "assessment/session_results#show", as: :exercise_session_result
# ADR-0105 §4.5 : l'image d'une question, sous la règle de lecture de son exercice.
get "images/questions/:public_id", to: "assessment/question_images#show", as: :question_image
# ADR-0120 questions à plusieurs cases §4 : l'ouverture de l'indice d'une question est un fait de la copie en cours.
post "exercise_sessions/:public_id/hints", to: "assessment/hints#create", as: :exercise_session_hints
# ADR hors-connexion §4.4 et §4.5 : le paquet de corrigé (JSON), la copie hors ligne (gardable) et l'envoi des copies en file.
get "exercises/:public_id/offline_pack", to: "assessment/offline_packs#show", as: :offline_pack_exercise
get "exercises/:public_id/offline_copy", to: "assessment/offline_copies#new", as: :offline_copy_exercise
post "offline_copies", to: "assessment/offline_copy_syncs#create", as: :offline_copies
