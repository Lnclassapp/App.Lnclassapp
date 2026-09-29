# 🧠 DOMAINE · UseCases::Identity::AcceptInvitation
# Rôle : le lien d'invitation crée un compte, une seule fois : team (second facteur enrôlé à la première connexion), ou
#        direction rattachée à son seul établissement, dans la même transaction
# ADR  : 0026, 0028 (exempté de policy : le visiteur n'a que le lien), 0031, 0038, 0050, 0065 · UDR : 0019, 0052
module UseCases
  module Identity
    class AcceptInvitation
      # Type d'invitation → rôle du compte créé (ADR-0038, ADR-0065).
      ROLES = { "team" => "team", "school_staff" => "school_admin" }.freeze
      CONTACT_TAKEN = { base: [ :contact_taken ] }.freeze

      def initialize(invitations:, registrations:, staffs:, audit_log:, transaction:, digest_key:, clock:)
        @invitations = invitations
        @registrations = registrations
        @staffs = staffs
        @audit_log = audit_log
        @transaction = transaction
        @digest_key = digest_key
        @clock = clock
      end

      # Avant d'afficher le formulaire. → success(Invitation) | :not_found | :expired (expirée, acceptée ou révoquée)
      def check(token:)
        invitation = @invitations.find_by_token_digest(token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key))
        return Shared::Result.failure(:not_found) if invitation.nil?
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
        attach_staff(invitation, user, now) if invitation.kind == "school_staff"
        @invitations.mark_accepted(id: invitation.id, user_id: user.id, at: now)
        @audit_log.record(action: "invitation.accepted", actor_id: user.id, at: now, subject_type: "Invitation",
                          subject_id: invitation.id, metadata: metadata(invitation))
        Shared::Result.success(user)
      end

      def attach_staff(invitation, user, now)
        @staffs.attach(user_id: user.id, school_id: invitation.school_id, invited_by_id: invitation.invited_by_id, at: now)
      end

      def metadata(invitation)
        return { team_role: invitation.team_role } if invitation.kind == "team"

        { kind: invitation.kind, school_id: invitation.school_id }
      end

      def user_from(invitation, dto)
        Entities::Identity::User.new(last_name: dto.last_name, first_name: dto.first_name, contact: invitation.contact,
                                     gender: dto.gender, role: ROLES.fetch(invitation.kind), team_role: invitation.team_role)
      end
    end
  end
end
