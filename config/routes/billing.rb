# 🌐 DELIVERY · routes du contexte billing, côté élève
# Rôle : Mon abonnement et la saisie d'un code de carte d'activation ; les écrans de l'équipe sont dans routes/teams.rb
# ADR  : cartes-activation (contexte billing) · UDR : abonnement-eleve
# Noms et chemins gelés par le Lot 0 ; les contrôleurs sont ceux des lots A et B.
get "abonnement", to: "billing/subscriptions#show", as: :billing_subscription
post "abonnement/activation", to: "billing/activations#create", as: :billing_activation
