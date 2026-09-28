# 🌐 DELIVERY · routes de l'espace direction ; tout contrôleur hérite de SchoolAdmin::BaseController
# Rôle : accueil, classes, enseignants, élèves, établissement (code, personnel) — toujours l'établissement de l'acteur
# ADR  : 0065, 0066 · UDR : 0052
# Aucun identifiant d'établissement dans une adresse : l'établissement est current_actor.school_id (UDR-0052 §3.0).
scope "school-admin", module: "school_admin", as: "school_admin" do
  get "/", to: "homes#show", as: :home
  resources :classrooms, only: %i[index show], param: :public_id
  # ADR-0059 : le « + » d'un niveau, sans le « − ».
  resources :level_classrooms, only: :create, path: "level-classrooms"
  # Avant les routes membres de `teachers` : « departed » n'est pas un identifiant public.
  get "teachers/departed", to: "departed_teachers#index", as: :departed_teachers
  resources :teachers, only: %i[index destroy], param: :public_id
  post "teachers/:public_id/reinstatement", to: "teacher_reinstatements#create", as: :teacher_reinstatement
  resources :students, only: :index
  # ADR-0065 : la recherche par matricule (seule `lookup` le reçoit) ; le changement de classe par l'identifiant public.
  resource :student_placement, only: :new, path: "students/placement" do
    post :lookup, on: :collection
  end
  get "students/:student_public_id/placement/edit", to: "student_placements#edit", as: :edit_student_placement
  patch "students/:student_public_id/placement", to: "student_placements#update", as: :update_student_placement
  resource :school, only: :show
  # PATCH seul (sans PUT) : 20 routes exactement, contrat de l'UDR-0052 §3.0.
  get "school/code", to: "school_codes#show", as: :school_code
  patch "school/code", to: "school_codes#update"
  resources :staff_members, only: %i[index destroy], path: "school/staff", param: :user_public_id
  resources :staff_invitations, only: %i[new create], path: "school/staff/invitations"
end
