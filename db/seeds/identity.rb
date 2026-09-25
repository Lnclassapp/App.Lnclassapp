# ADR-0034, ADR-0038: the only seed of production. While no team account exists, TEAM_BOOTSTRAP_CONTACT receives
# the first team invitation (admin, invited by nobody); its link is printed once, only its digest is stored.
# No account and no PIN live in the repository.
contact = ENV["TEAM_BOOTSTRAP_CONTACT"].presence

if contact && !Orm::User.exists?(role: "team")
  now = Time.current
  open_invitations = Orm::Invitation.where(kind: "team", contact:, accepted_at: nil, revoked_at: nil)

  if open_invitations.exists?([ "expires_at > ?", now ])
    puts "Une invitation d'amorçage attend déjà #{contact} : son lien a été affiché à sa création."
  else
    open_invitations.update_all(revoked_at: now, updated_at: now)
    token = Entities::Identity::Invitation.generate_token
    key = Rails.application.key_generator.generate_key("lnclass-secrets")
    Orm::Invitation.create!(kind: "team", contact:, team_role: "admin", invited_by_id: nil,
                            token_digest: Entities::Identity::SecretDigest.hmac(token, key:),
                            expires_at: now + Entities::Identity::Invitation::TTL)
    puts "Invitation d'amorçage pour #{contact}, valable 72 h, affichée une seule fois : " \
         "#{Rails.application.routes.url_helpers.invitation_path(token)}"
  end
end
