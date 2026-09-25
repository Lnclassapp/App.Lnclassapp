# 🧠 DOMAINE · UseCases::Identity::InviteTeamMember
# Rôle : un admin de l'équipe invite un numéro ; seule l'empreinte du jeton est gardée, le jeton en clair ne sort qu'une fois
# ADR  : 0026, 0028, 0038, 0050 · UDR : 0019
module UseCases
  module Identity
    class InviteTeamMember
      Invited = Data.define(:invitation, :token)
      KIND = "team".freeze

      def initialize(invitations:, users:, audit_log:, transaction:, policy:, digest_key:, clock:)
        @invitations = invitations
        @users = users
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::TeamInvitationInput. Le contrôleur fait du jeton l'URL /invitations/<jeton>.
      # → success(Invited) | :forbidden | :invalid | :conflict (numéro déjà lié à un compte, invitation en cours)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?
        return Shared::Result.failure(:conflict, errors: { contact: [ :taken ] }) if @users.find_by_contact(contact: dto.contact)

        @transaction.call { invite(actor, dto, Entities::Identity::Invitation.generate_token, @clock.now) }
      end

      private

      # Une invitation expirée, jamais acceptée, occupe encore l'index partiel : révoquée, elle libère le numéro.
      def invite(actor, dto, token, now)
        @invitations.revoke_expired(kind: KIND, contact: dto.contact, at: now)
        created = @invitations.create(kind: KIND, contact: dto.contact, team_role: dto.team_role, invited_by_id: actor.user_id,
                                      token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key),
                                      expires_at: now + Entities::Identity::Invitation::TTL)
        return created if created.failure?

        @audit_log.record(action: "invitation.sent", actor_id: actor.user_id, at: now, subject_type: "Invitation",
                          subject_id: created.value.id, metadata: { team_role: dto.team_role })
        Shared::Result.success(Invited.new(invitation: created.value, token:))
      end
    end
  end
end
