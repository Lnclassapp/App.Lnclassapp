# 🌐 DELIVERY · routes de l'espace direction ; tout contrôleur hérite de SchoolAdmin::BaseController
# Rôle : lectures de la direction sur son seul établissement, et ses trois gestes (lien, classes d'un niveau, enseignants)
# ADR  : 0036, 0065, 0071 · UDR : 0052, 0056, 0072 · l'établissement vient toujours du compte, jamais d'un paramètre
scope "school-admin", module: "school_admin", as: "school_admin" do
  resources :classrooms, only: %i[index show], param: :public_id
  # UDR-0072 §3.8, §3.11 : la page d'un niveau, par son slug figé ; l'activité récente, frame différé de l'accueil.
  resources :levels, only: :show, param: :slug
  get "activity", to: "activities#show", as: :activity
  # ADR-0036, lot R de fonctions-espace-eleve : l'établissement quitté garde les résultats obtenus chez lui.
  get "students/departed", to: "departed_students#index", as: :departed_students
  # Avant `resources :teachers` : « departed » n'est pas un public_id.
  get "teachers/departed", to: "departed_teachers#index", as: :departed_teachers
  resources :teachers, only: %i[index destroy], param: :public_id
  post "teachers/:public_id/reinstatement", to: "teacher_reinstatements#create", as: :teacher_reinstatement
  resource :school, only: :show
  # PATCH seul : `resource :link` ajouterait un PUT que l'UDR-0056 §3.0 ne dessine pas.
  patch "school/link", to: "school_links#update", as: :school_link
  # Sous /school-admin/school, sans le préfixe de nom « school_ » (UDR-0056 §3.0 : school_admin_level_classrooms_path).
  scope "school" do
    resources :level_classrooms, only: %i[create destroy], path: "level-classrooms", param: :public_id
  end
end
