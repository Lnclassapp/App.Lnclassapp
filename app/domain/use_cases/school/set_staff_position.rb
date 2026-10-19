# 🧠 DOMAINE · UseCases::School::SetStaffPosition
# Rôle : l'équipe change la fonction d'une direction active, sous la règle du chef unique ; journal school_staff.position_set
# ADR  : 0028, 0092 (§4.3) · UDR : 0092 (§3.4) · le chef unique est revérifié par le repository, sous le verrou de l'établissement
module UseCases
  module School
    class SetStaffPosition
      # staff : le rattachement avant le changement ; user : le compte, pour le nom du toast.
      Changed = Data.define(:staff, :user, :position)
      ACTION = "school_staff.position_set".freeze
      HEAD_TAKEN = { position: [ :head_taken ] }.freeze

      def initialize(staff:, users:, audit_log:, policy:, transaction:, clock:)
        @staff = staff
        @users = users
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # target_public_id : public_id du compte (users.public_id) ; dto : Dtos::School::StaffPositionInput.
      # → success(Changed) | :forbidden (policy) | :invalid (fonction absente ou inconnue) | :not_found (absent ou archivé)
      #   | failure(:conflict, errors: { position: [:head_taken] }) (un autre chef d'établissement est actif)
      def call(actor:, target_public_id:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        target = @staff.find_by_public_id(public_id: target_public_id)
        return Shared::Result.failure(:not_found) if target.nil? || target.archived?

        @transaction.call { change(actor, target, dto.position) }
      end

      private

      # « Même fonction » n'écrit rien et ne journalise rien : la modale se ferme comme après un changement.
      def change(actor, target, position)
        outcome, previous = @staff.set_position(user_id: target.user_id, position:)
        case outcome
        when :head_taken then Shared::Result.failure(:conflict, errors: HEAD_TAKEN)
        when :not_found then Shared::Result.failure(:not_found)
        when :set
          # « from » : la fonction lue sous le verrou par le repository, pas celle de la cible lue avant.
          @audit_log.record(action: ACTION, actor_id: actor.user_id, at: @clock.now, subject_type: "User", subject_id: target.user_id,
                            metadata: { school_id: target.school_id, from: previous, to: position })
          changed(target, position)
        else changed(target, position)
        end
      end

      def changed(target, position) = Shared::Result.success(Changed.new(staff: target, user: @users.find(id: target.user_id), position:))
    end
  end
end
