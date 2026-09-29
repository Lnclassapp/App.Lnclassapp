# Every V1 route is drawn here once, by context (plan boucle-pedagogique §0a.4); no vertical
# lot edits them. A route whose controller is not merged yet breaks nothing until it is called.
# No numeric :id anywhere (ADR-0029): public_id or slug only.
Rails.application.routes.draw do
  root to: "homepage#index"
  draw(:design) unless Rails.env.production?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  draw :identity
  draw :school
  draw :classroom
  draw :catalog
  draw :assessment
  draw :communication
  draw :teams
  draw :school_admin
end
