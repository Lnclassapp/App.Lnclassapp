# 🌐 DELIVERY · routes du contexte identity
# Rôle : connexion, session, second facteur, PIN oublié, inscription enseignant, invitations, profil
# ADR  : 0031, 0032, 0038, 0050, 0055, 0057, 0060, 0063, 0071, 0077, 0083
get "login", to: "identity/sessions#new", as: :new_session
resource :session, only: %i[create destroy], controller: "identity/sessions" # session_path, gelé : DELETE = « Se déconnecter »
namespace :identity do
  resource :second_factor, only: %i[new create], path: "second-factor"
  resource :second_factor_enrollment, only: %i[new create], path: "second-factor/enrollment"
  resource :pin_reset, only: %i[new create], path: "pin-reset"
end
get "account/pending", to: "identity/pending_accounts#show", as: :pending_account
# ADR-0071, ADR-0083 §4.3 : un enseignant sans établissement (retiré, demande refusée) choisit DRENA puis établissement.
post "account/pending/school", to: "identity/pending_school_joins#create", as: :pending_school_join
get "teacher-signup", to: "identity/teacher_registrations#new", as: :new_teacher_registration
post "teacher-signup", to: "identity/teacher_registrations#create", as: :teacher_registrations
# ADR-0077 : la direction s'inscrit seule avec le code d'établissement (plafond de 3 par le code).
get "school-staff-signup", to: "identity/school_staff_registrations#new", as: :new_school_staff_registration
post "school-staff-signup", to: "identity/school_staff_registrations#create", as: :school_staff_registrations
# ADR-0083 §4.1 : le lien d'invitation d'un collègue, de la direction ou de l'équipe ouvre l'inscription, établissement choisi.
get "i/:token", to: "identity/teacher_registrations#invite", as: :teacher_invite_link
# ADR-0063 : « Inviter un collègue » ; un clic « Partager » est enregistré par le serveur (204), sur la session.
get "teachers/invite", to: "identity/referrals#show", as: :teacher_invite
post "teachers/invite/shares", to: "identity/referral_shares#create", as: :teacher_referral_shares
get "invitations/:token", to: "identity/invitations#show", as: :invitation
post "invitations/:token", to: "identity/invitations#accept", as: :accept_invitation
post "accounts/:user_public_id/pin-recovery-codes", to: "identity/pin_recovery_codes#create", as: :account_pin_recovery_codes
# La photo d'un compte, sous session et ReadUserPolicy ; jamais une route Active Storage (ADR-0060).
get "accounts/:user_public_id/photo", to: "identity/account_photos#show", as: :account_photo
# Le profil ne prend aucun identifiant : toujours le compte de la session (ADR-0055). profile_path, gelé : « Mon profil ».
scope module: :identity do
  resource :profile, only: :show do
    resource :name, only: %i[edit update], controller: :profile_names
    resource :contact, only: %i[edit update], controller: :profile_contacts
    resource :pin, only: %i[edit update], controller: :profile_pins
    resource :photo, only: %i[edit update destroy], controller: :profile_photos
  end
end
