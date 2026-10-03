# 🌐 DELIVERY · routes de l'espace équipe ; tout contrôleur hérite de Teams::BaseController
# Rôle : référentiel, DRENA, établissements, contenu, blog, imports, invitations, comptes, jobs
# ADR  : 0031, 0034, 0036 (amendement 2), 0038, 0039, 0052, 0056, 0057, 0058, 0059, 0062, 0063, 0065, 0074 · UDR : 0067
get "teams", to: "teams/homes#show", as: :team_home # gelé
# ADR-0062, UDR-0049 : le pilotage, nom de route gelé par l'UDR-0006 (entrée « Pilotage » de la navigation équipe).
get "teams/dashboard", to: "teams/dashboards#show", as: :team_dashboard

# Noms sans préfixe, attendus par la navigation du shell (schools_path).
scope "teams", module: "teams" do
  resources :drenas, param: :public_id, except: :show
  # ADR-0056 : génération des classes manquantes, suivie dans son rapport (teams/imports). Avant `schools` : chemin fixe.
  post "schools/classroom-generations", to: "classroom_generations#create", as: :classroom_generations
  # Aucun formulaire de création : les établissements n'entrent que par import JSON (teams/imports, kind « schools »).
  resources :schools, param: :public_id, except: %i[new create] do
    member { patch :deactivate }
    resources :classrooms, only: %i[new create], controller: "school_classrooms"
    # ADR-0057 : régénération du code d'établissement (PATCH seul ; le code se lit sur la fiche).
    resource :code, only: :update, controller: "school_codes"
    # ADR-0063 : valider ou refuser un enseignant inscrit sans code (decision=approve|reject).
    resources :join_requests, only: :update, path: "join-requests", param: :public_id
    # ADR-0059 : « + » et « − » du bloc « Classes par niveau » de la fiche.
    resources :level_classrooms, only: %i[create destroy], path: "level-classrooms", param: :public_id
    # ADR-0065 : inviter la direction depuis la fiche (modale de l'UDR-0052).
    resources :staff_invitations, only: %i[new create], path: "staff-invitations"
  end
  resources :levels, param: :slug, except: :show
  resources :series, param: :slug, except: :show
  resources :level_series, only: %i[create destroy], path: "levels/:level_slug/series", param: :series_slug
  resources :materials, param: :slug, except: :show
  # ADR-0058 : le barème des classes ; une ligne = un niveau du premier cycle, ou un couple niveau × série liée.
  get "classroom-plan", to: "classroom_plans#show", as: :classroom_plan
  get "classroom-plan/:level_slug(/:series_slug)/edit", to: "classroom_plans#edit", as: :edit_classroom_plan_line
  patch "classroom-plan/:level_slug(/:series_slug)", to: "classroom_plans#update", as: :classroom_plan_line
end

# ADR-0074 §6, UDR-0067 §3.0 : la gestion du blog, adressée par public_id. Les images avant les articles : chemin fixe.
scope "teams/blog", as: :teams do
  post "images", to: "teams/article_images#create", as: :article_images
  resources :articles, path: "", controller: "teams/articles", param: :public_id, only: %i[index new create edit update] do
    member { patch :publish; patch :archive }
  end
end

namespace :teams do
  resources :courses, only: %i[new create edit update], param: :slug do
    member { patch :publish; patch :archive; patch :publish_all, path: "publish-all" }
    resources :essentials, only: %i[new create], param: :slug
  end
  resources :essentials, only: %i[edit update], param: :slug do
    member { patch :publish; patch :archive; patch :publish_all, path: "publish-all" }
    resources :exercises, only: %i[new create]
  end
  resources :exercises, only: %i[edit update], param: :public_id do
    member { patch :publish; patch :archive }
  end
  resources :imports, only: %i[index new create show], param: :public_id
  resources :invitations, only: %i[new create]
  resource :account_lookup, only: :show, path: "accounts"
  # ADR-0036 §4 : une demande de suppression d'un compte élève, datée, traitée depuis la fiche du compte (modale).
  resource :account_deletion, only: %i[new create], path: "accounts/:user_public_id/deletion"
  # ADR-0036, amendement 2 : une demande de suppression s'enregistre à sa réception et s'annule depuis la fiche du compte
  # (bloc chargé dans un frame) ; la liste des demandes en attente se lit par échéance.
  resource :deletion_request, only: %i[show new create destroy], path: "accounts/:user_public_id/deletion-request"
  resources :deletion_requests, only: :index, path: "deletion-requests"
  # ADR-0063 : « Croissance », indicateurs du parrainage ; liée depuis l'accueil, sans entrée de navigation (UDR-0006).
  resource :growth, only: :show, controller: "growth"
  post "members/:user_public_id/second-factor-reset", to: "second_factor_resets#create", as: :member_second_factor_reset

  # ADR-0052 : failed jobs are read and retried here, behind the team area authentication.
  mount MissionControl::Jobs::Engine, at: "/jobs"
end
