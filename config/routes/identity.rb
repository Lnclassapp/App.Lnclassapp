# 🌐 DELIVERY · routes du contexte identity
# Rôle : connexion, session, second facteur, PIN oublié, inscription enseignant, invitations, profil
# ADR  : 0031, 0032, 0038, 0050, 0055, 0057, 0063
get "login", to: "identity/sessions#new", as: :new_session
resource :session, only: %i[create destroy], controller: "identity/sessions" # session_path, gelé : DELETE = « Se déconnecter »
namespace :identity do
  resource :second_factor, only: %i[new create], path: "second-factor"
  resource :second_factor_enrollment, only: %i[new create], path: "second-factor/enrollment"
  resource :pin_reset, only: %i[new create], path: "pin-reset"
end
get "account/pending", to: "identity/pending_accounts#show", as: :pending_account
get "teacher-signup", to: "identity/teacher_registrations#new", as: :new_teacher_registration
post "teacher-signup", to: "identity/teacher_registrations#create", as: :teacher_registrations
# ADR-0063 : « Mon établissement n'a pas encore de code Lnclass » : code national ou DRENA → établissement, compte en attente.
get "teacher-signup/without-code", to: "identity/pending_teacher_registrations#new", as: :new_pending_teacher_registration
post "teacher-signup/without-code", to: "identity/pending_teacher_registrations#create", as: :pending_teacher_registrations
# ADR-0057 : le lien à partager d'un code d'établissement ouvre l'inscription, établissement déjà trouvé (limité en débit).
get "e/:code", to: "identity/teacher_registrations#with_code", as: :school_code_signup
# ADR-0063 : « Inviter un collègue » ; un clic « Partager » est enregistré par le serveur (204), sur la session.
get "teachers/invite", to: "identity/referrals#show", as: :teacher_invite
post "teachers/invite/shares", to: "identity/referral_shares#create", as: :teacher_referral_shares
get "invitations/:token", to: "identity/invitations#show", as: :invitation
post "invitations/:token", to: "identity/invitations#accept", as: :accept_invitation
post "accounts/:user_public_id/pin-recovery-codes", to: "identity/pin_recovery_codes#create", as: :account_pin_recovery_codes
# Le profil ne prend aucun identifiant : toujours le compte de la session (ADR-0055). profile_path, gelé : « Mon profil ».
scope module: :identity do
  resource :profile, only: :show do
    resource :name, only: %i[edit update], controller: :profile_names
    resource :contact, only: %i[edit update], controller: :profile_contacts
    resource :pin, only: %i[edit update], controller: :profile_pins
  end
end
