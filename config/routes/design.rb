# 🌐 DELIVERY · routes du guide de style (/design), hors production
# Rôle : catalogue des composants, aperçu du shell de chaque rôle, démonstration du CRUD Hotwire
# UDR  : 0005, 0006
scope :design, controller: :design, as: :design do
  get "/", action: :index
  get "shell/:role", action: :shell, as: :shell, constraints: { role: /student|teacher|team|school_admin/ }
  post "toast", action: :toast, as: :toast
  get "modal", action: :modal, as: :modal
  post "modal", action: :create
  get "frame", action: :frame, as: :frame
end
