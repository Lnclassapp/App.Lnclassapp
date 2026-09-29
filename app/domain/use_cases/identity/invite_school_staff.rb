# 🧠 DOMAINE · UseCases::Identity::InviteSchoolStaff
# Rôle : l'équipe invite la direction d'un établissement actif, sans fonction ; le jeton en clair ne sort qu'une fois
# ADR  : 0026, 0028, 0038, 0050, 0065 · UDR : 0019, 0052
module UseCases
  module Identity
    class InviteSchoolStaff
      Invited = Data.define(:invitation, :token)
      KIND = "school_staff".freeze
      INACTIVE = { school: [ :inactive ] }.freeze

      def initialize(invitations:, users:, schools:, audit_log:, transaction:, policy:, digest_key:, clock:)
        @invitations = invitations
        @users = users
        @schools = schools
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::SchoolStaffInvitationInput. Le contrôleur fait du jeton l'URL /invitations/<jeton>.
      # → success(Invited) | :forbidden | :not_found (établissement inconnu) | :invalid (dont school: [:inactive])
      #   | :conflict (numéro déjà lié à un compte, invitation en cours)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        school = @schools.find_by_public_id(public_id: dto.school_public_id)
        return Shared::Result.failure(:not_found) if school.nil?
        return Shared::Result.failure(:invalid, errors: INACTIVE) unless school.active?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?
        return Shared::Result.failure(:conflict, errors: { contact: [ :taken ] }) if @users.find_by_contact(contact: dto.contact)

        @transaction.call { invite(actor, dto.contact, school.id, Entities::Identity::Invitation.generate_token, @clock.now) }
      end

      private

      # Une invitation expirée, jamais acceptée, occupe encore l'index partiel : révoquée, elle libère le numéro.
      def invite(actor, contact, school_id, token, now)
        @invitations.revoke_expired(kind: KIND, contact:, at: now)
        created = @invitations.create(kind: KIND, contact:, team_role: nil, school_id:, position: nil, invited_by_id: actor.user_id,
                                      token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key),
                                      expires_at: now + Entities::Identity::Invitation::TTL)
        return created if created.failure?

        @audit_log.record(action: "invitation.sent", actor_id: actor.user_id, at: now, subject_type: "Invitation",
                          subject_id: created.value.id, metadata: { kind: KIND, school_id: })
        Shared::Result.success(Invited.new(invitation: created.value, token:))
      end
    end
  end
end
