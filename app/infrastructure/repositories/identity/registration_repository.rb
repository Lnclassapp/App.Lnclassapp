# 🔌 INFRA · Repositories::Identity::RegistrationRepository
# Rôle : crée les comptes (élève, enseignant, direction, invité) ; un numéro déjà pris devient :conflict
# ADR  : 0026, 0030, 0038, 0050, 0077, 0083
module Repositories
  module Identity
    class RegistrationRepository
      include Ports::Identity::RegistrationRepositoryPort

      TAKEN = { contact: [ :taken ] }.freeze

      def create_student(user:, pin:)
        create(user, pin, role: "student")
      end

      def create_teacher(user:, pin:, material_id:, joined_via:)
        create(user, pin, role: "teacher") do |record|
          Orm::TeacherProfile.create!(user_id: record.id, material_id:, joined_via:)
        end
      end

      def create_school_admin(user:, pin:)
        create(user, pin, role: "school_admin")
      end

      def create_from_invitation(user:, pin:, invitation_id:, at:)
        create(user, pin, role: user.role, team_role: user.team_role) do |record|
          Orm::Invitation.where(id: invitation_id).update_all(accepted_at: at, accepted_user_id: record.id, updated_at: at)
        end
      end

      private

      # Point de sauvegarde : l'index unique refusé n'invalide pas la transaction du use case.
      def create(user, pin, role:, team_role: nil)
        record = Orm::User.transaction(requires_new: true) do
          Orm::User.create!(last_name: user.last_name, first_name: user.first_name, contact: user.contact,
                            gender: user.gender, role:, team_role:, pin:).tap { |created| yield created if block_given? }
        end
        ::Shared::Result.success(map(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: TAKEN)
      end

      def map(record)
        Entities::Identity::User.new(
          id: record.id, public_id: record.public_id, last_name: record.last_name, first_name: record.first_name,
          contact: record.contact, gender: record.gender, role: record.role, team_role: record.team_role
        )
      end
    end
  end
end
