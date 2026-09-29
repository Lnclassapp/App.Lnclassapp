# ADR-0034, ADR-0038: the only seed of production. While no team account exists, TEAM_BOOTSTRAP_CONTACT receives
# the first team invitation (admin, invited by nobody); its link is printed at each run until then, only its digest is stored.
# No account and no PIN live in the repository.
contact = ENV["TEAM_BOOTSTRAP_CONTACT"].presence

if contact && !Orm::User.exists?(role: "team")
  now = Time.current
  # Every run revokes the open invitation and prints a new link: the logs of the pre-deploy may be cut when Railway
  # stops its container, and a link printed once and lost would leave no way in.
  Orm::Invitation.where(kind: "team", contact:, accepted_at: nil, revoked_at: nil).update_all(revoked_at: now, updated_at: now)
  token = Entities::Identity::Invitation.generate_token
  key = Rails.application.key_generator.generate_key("lnclass-secrets")
  Orm::Invitation.create!(kind: "team", contact:, team_role: "admin", invited_by_id: nil,
                          token_digest: Entities::Identity::SecretDigest.hmac(token, key:),
                          expires_at: now + Entities::Identity::Invitation::TTL)
  puts "Invitation d'amorçage pour #{contact}, valable 72 h : " \
       "#{Rails.application.routes.url_helpers.invitation_path(token)}"
  $stdout.flush
end
