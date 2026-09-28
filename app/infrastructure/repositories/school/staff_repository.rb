# 🔌 INFRA · Repositories::School::StaffRepository
# Rôle : rattachements de la direction (school_staffs) ; un établissement actif par membre et un Proviseur actif, par index
# ADR  : 0044, 0066
module Repositories
  module School
    class StaffRepository
      include Ports::School::StaffRepositoryPort

      PRINCIPAL_INDEX = "index_school_staffs_one_principal".freeze
      OTHER_SCHOOL = { base: [ :other_school ] }.freeze
      PRINCIPAL_TAKEN = { position: [ :principal_taken ] }.freeze

      # Aucun CHECK ne peut lire users : le rôle du compte est vérifié ici. Savepoint : l'index unique refusé n'invalide pas
      # la transaction du use case ; son nom dit lequel.
      def attach(user_id:, school_id:, position:, invited_by_id:, at:)
        raise ArgumentError, "le compte #{user_id} n'est pas de la direction" unless Orm::User.exists?(id: user_id, role: "school_admin")

        record = Orm::SchoolStaff.transaction(requires_new: true) do
          Orm::SchoolStaff.create!(user_id:, school_id:, position:, invited_by_id:, joined_at: at)
        end
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique => error
        ::Shared::Result.failure(:conflict, errors: error.message.include?(PRINCIPAL_INDEX) ? PRINCIPAL_TAKEN : OTHER_SCHOOL)
      end

      def find_active(user_public_id:, school_id:)
        record = Orm::SchoolStaff.active.joins(:user).find_by(school_id:, users: { public_id: user_public_id })
        record && map_to_entity(record)
      end

      def principal_active?(school_id:) = Orm::SchoolStaff.active.exists?(school_id:, position: "principal")

      def detach(id:, at:)
        Orm::SchoolStaff.where(id:).update_all(left_at: at)
        true
      end

      private

      def map_to_entity(record)
        Entities::School::StaffMember.new(id: record.id, user_id: record.user_id, school_id: record.school_id,
                                          position: record.position, invited_by_id: record.invited_by_id,
                                          joined_at: record.joined_at, left_at: record.left_at)
      end
    end
  end
end
