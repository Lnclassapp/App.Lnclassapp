# 🌐 DELIVERY · routes de l'espace direction ; tout contrôleur hérite de SchoolAdmin::BaseController
# Rôle : lectures de la direction sur son seul établissement, GET seulement (DS-11) ; l'établissement vient du compte
# ADR  : 0065 · UDR : 0052
scope "school-admin", module: "school_admin", as: "school_admin" do
  resources :classrooms, only: %i[index show], param: :public_id
  resources :teachers, only: :index
end
