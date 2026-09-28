# 🌐 DELIVERY · routes de l'espace équipe ; tout contrôleur hérite de Teams::BaseController
# Rôle : référentiel, DRENA, établissements, contenu, imports, invitations, comptes, jobs
# ADR  : 0031, 0034, 0038, 0039, 0052, 0056, 0059
get "teams", to: "teams/homes#show", as: :team_home # gelé

# Noms sans préfixe, attendus par la navigation du shell (schools_path).
scope "teams", module: "teams" do
  resources :drenas, param: :public_id, except: :show
  # ADR-0056 : génération des classes manquantes, suivie dans son rapport (teams/imports). Avant `schools` : chemin fixe.
  post "schools/classroom-generations", to: "classroom_generations#create", as: :classroom_generations
  # Aucun formulaire de création : les établissements n'entrent que par import JSON (teams/imports, kind « schools »).
  resources :schools, param: :public_id, except: %i[new create] do
    member { patch :deactivate }
    resources :classrooms, only: %i[new create], controller: "school_classrooms"
    # ADR-0059 : « + » et « − » du bloc « Classes par niveau » de la fiche.
    resources :level_classrooms, only: %i[create destroy], path: "level-classrooms", param: :public_id
  end
  resources :levels, param: :slug, except: :show
  resources :series, param: :slug, except: :show
  resources :level_series, only: %i[create destroy], path: "levels/:level_slug/series", param: :series_slug
  resources :materials, param: :slug, except: :show
end

namespace :teams do
  resources :courses, only: %i[new create edit update], param: :slug do
    member { patch :publish; patch :archive }
    resources :essentials, only: %i[new create], param: :slug
  end
  resources :essentials, only: %i[edit update], param: :slug do
    member { patch :publish; patch :archive }
    resources :exercises, only: %i[new create]
  end
  resources :exercises, only: %i[edit update], param: :public_id do
    member { patch :publish; patch :archive }
  end
  resources :imports, only: %i[index new create show], param: :public_id
  resources :invitations, only: %i[new create]
  resource :account_lookup, only: :show, path: "accounts"
  post "members/:user_public_id/second-factor-reset", to: "second_factor_resets#create", as: :member_second_factor_reset

  # ADR-0052 : failed jobs are read and retried here, behind the team area authentication.
  mount MissionControl::Jobs::Engine, at: "/jobs"
end
