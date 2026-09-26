# 🧠 DOMAINE · UseCases::Identity::AcceptInvitation
# Rôle : le lien d'invitation crée un compte team, une seule fois ; le second facteur s'enrôle à la première connexion
# ADR  : 0026, 0028 (exempté de policy : le visiteur n'a que le lien), 0031, 0038, 0050 · UDR : 0019
module UseCases
  module Identity
    class AcceptInvitation
      ROLE = "team".freeze
      CONTACT_TAKEN = { base: [ :contact_taken ] }.freeze

      def initialize(invitations:, registrations:, audit_log:, transaction:, digest_key:, clock:)
        @invitations = invitations
        @registrations = registrations
        @audit_log = audit_log
        @transaction = transaction
        @digest_key = digest_key
        @clock = clock
      end

      # Avant d'afficher le formulaire. → success(Invitation) | :not_found | :expired (expirée, acceptée ou révoquée)
      def check(token:)
        invitation = @invitations.find_by_token_digest(token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key))
        # Une invitation de direction (ADR-0044) ne s'accepte pas par cet écran.
        return Shared::Result.failure(:not_found) unless invitation&.kind == ROLE
        return Shared::Result.failure(:expired) unless invitation.status(now: @clock.now) == :pending

        Shared::Result.success(invitation)
      end

      # dto : Dtos::Identity::InvitationAcceptanceInput. Le lien périmé l'emporte sur un formulaire invalide.
      # → success(User) | :not_found | :expired | :invalid | :conflict (numéro devenu un compte entre-temps)
      def call(token:, dto:)
        checked = check(token:)
        return checked if checked.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        @transaction.call { accept(checked.value, dto, @clock.now) }
      end

      private

      def accept(invitation, dto, now)
        created = @registrations.create_from_invitation(user: user_from(invitation, dto), pin: dto.pin,
                                                        invitation_id: invitation.id, at: now)
        return Shared::Result.failure(:conflict, errors: CONTACT_TAKEN) if created.failure?

        user = created.value
        @invitations.mark_accepted(id: invitation.id, user_id: user.id, at: now)
        @audit_log.record(action: "invitation.accepted", actor_id: user.id, at: now, subject_type: "Invitation",
                          subject_id: invitation.id, metadata: { team_role: invitation.team_role })
        Shared::Result.success(user)
      end

      def user_from(invitation, dto)
        Entities::Identity::User.new(last_name: dto.last_name, first_name: dto.first_name, contact: invitation.contact,
                                     gender: dto.gender, role: ROLE, team_role: invitation.team_role)
      end
    end
  end
end
