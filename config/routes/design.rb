# 🌐 DELIVERY · routes du guide de style (/design), hors production
# Rôle : catalogue des composants et aperçu du shell de chaque rôle
# UDR  : 0005, 0006
scope :design, controller: :design, as: :design do
  get "/", action: :index
  get "shell/:role", action: :shell, as: :shell, constraints: { role: /student|teacher|team|school_admin/ }
  post "toast", action: :toast, as: :toast
end
