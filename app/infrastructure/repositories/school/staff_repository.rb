# 🔌 INFRA · Repositories::School::StaffRepository
# Rôle : écrit le rattachement d'un compte de direction à son établissement (table school_staffs), le plafond sous verrou
# ADR  : 0036, 0065, 0077
module Repositories
  module School
    class StaffRepository
      include Ports::School::StaffRepositoryPort

      CODE = "code".freeze
      COLUMNS = [ :user_id, "users.public_id", :school_id, :joined_via, :created_at, :archived_at, :archived_by_id ].freeze

      def attach(user_id:, school_id:, invited_by_id:, at:)
        Orm::SchoolStaff.create!(user_id:, school_id:, invited_by_id:, created_at: at)
        true
      end

      def attach_by_code(user_id:, school_id:, cap:, at:)
        Orm::SchoolStaff.transaction do
          lock_school(school_id)
          next false if by_code_count(school_id) >= cap

          Orm::SchoolStaff.create!(user_id:, school_id:, joined_via: CODE, created_at: at)
          true
        end
      end

      def find_by_user_id(user_id:) = first(Orm::SchoolStaff.where(user_id:))

      def find_by_public_id(public_id:) = first(Orm::SchoolStaff.where(users: { public_id: }))

      # Sous le verrou de l'établissement, comme attach_by_code et restore : les retraits d'un même établissement se sérialisent.
      def archive(user_id:, by_id:, at:)
        Orm::SchoolStaff.transaction do
          school_id = Orm::SchoolStaff.active.where(user_id:).pick(:school_id)
          next false if school_id.nil?

          lock_school(school_id)
          Orm::SchoolStaff.active.where(user_id:).update_all(archived_at: at, archived_by_id: by_id) == 1
        end
      end

      # La ligne est relue sous le verrou : une purge ou une autre restauration validée entre-temps donne :not_archived,
      # jamais un second :restored (revue de sécurité du Lot C, constat 2).
      def restore(user_id:, cap:)
        Orm::SchoolStaff.transaction do
          school_id = Orm::SchoolStaff.where(user_id:).pick(:school_id)
          next :not_archived if school_id.nil?

          lock_school(school_id)
          joined_via = Orm::SchoolStaff.where(user_id:).where.not(archived_at: nil).pick(:joined_via)
          next :not_archived if joined_via.nil?
          next :cap_reached if joined_via == CODE && by_code_count(school_id) >= cap

          Orm::SchoolStaff.where(user_id:).where.not(archived_at: nil).update_all(archived_at: nil, archived_by_id: nil)
          :restored
        end
      end

      def claim_for_purge(user_id:, before:)
        school_id = Orm::SchoolStaff.where(user_id:).pick(:school_id)
        return false if school_id.nil?

        lock_school(school_id)
        Orm::SchoolStaff.where(user_id:, archived_at: ...before).exists?
      end

      def archived_before(at:) = rows(Orm::SchoolStaff.where(archived_at: ...at).order(:archived_at, :id))

      def delete(user_id:)
        Orm::SchoolStaff.where(user_id:).delete_all
        true
      end

      private

      # Deux inscriptions sur la dernière place se sérialisent sur la ligne de l'établissement (ADR-0077 §6).
      def lock_school(school_id) = Orm::School.lock.where(id: school_id).pick(:id)

      def by_code_count(school_id) = Orm::SchoolStaff.active.where(school_id:, joined_via: CODE).count

      def first(scope) = rows(scope.limit(1)).first

      def rows(scope) = scope.joins(:user).pluck(*COLUMNS).map { Entities::School::Staff.new(*it) }
    end
  end
end
