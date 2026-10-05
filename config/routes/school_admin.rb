# 🌐 DELIVERY · routes de l'espace direction ; tout contrôleur hérite de SchoolAdmin::BaseController
# Rôle : lectures de la direction sur son seul établissement, et ses trois gestes (lien, classes d'un niveau, enseignants)
# ADR  : 0036, 0065, 0071, 0077 · UDR : 0052, 0056, 0070 · l'établissement vient toujours du compte, jamais d'un paramètre
scope "school-admin", module: "school_admin", as: "school_admin" do
  resources :classrooms, only: %i[index show], param: :public_id
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
    # ADR-0077 : retirer une autre direction de l'établissement (public_id du compte).
    resources :staff_members, only: :destroy, path: "staff", param: :public_id
  end
end
