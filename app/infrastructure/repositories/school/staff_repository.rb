# 🔌 INFRA · Repositories::School::StaffRepository
# Rôle : écrit le rattachement d'un compte de direction à son établissement (table school_staffs), le plafond sous verrou
# ADR  : 0036, 0065, 0077, 0092 · le chef unique : relu sous le verrou de l'établissement, l'index partiel en dernier recours
module Repositories
  module School
    class StaffRepository
      include Ports::School::StaffRepositoryPort

      CODE = "code".freeze
      HEAD = Entities::School::StaffPosition::HEAD
      ONE_HEAD_INDEX = "index_school_staffs_one_active_head".freeze
      COLUMNS = [ :user_id, "users.public_id", :school_id, :joined_via, :created_at, :archived_at, :archived_by_id, :position ].freeze

      def attach(user_id:, school_id:, invited_by_id:, position:, at:)
        locked(school_id) do
          next :head_taken if position == HEAD && head_taken?(school_id:)

          insert(user_id:, school_id:, invited_by_id:, position:, created_at: at)
        end
      end

      def attach_by_code(user_id:, school_id:, cap:, position:, at:)
        locked(school_id) do
          next :cap_reached if by_code_count(school_id) >= cap
          next :head_taken if position == HEAD && head_taken?(school_id:)

          insert(user_id:, school_id:, joined_via: CODE, position:, created_at: at)
        end
      end

      def head_taken?(school_id:, except_user_id: nil)
        Orm::SchoolStaff.active.where(school_id:, position: HEAD).where.not(user_id: except_user_id).exists?
      end

      def set_position(user_id:, position:)
        Orm::SchoolStaff.transaction do
          school_id = Orm::SchoolStaff.where(user_id:).pick(:school_id)
          next :not_found if school_id.nil?

          # Relue sous le verrou : un retrait validé entre-temps la rend introuvable.
          lock_school(school_id)
          current = Orm::SchoolStaff.active.where(user_id:).pick(:position)
          next :not_found if current.nil?
          next :unchanged if current == position
          next :head_taken if position == HEAD && head_taken?(school_id:, except_user_id: user_id)

          guarded { Orm::SchoolStaff.where(user_id:).update_all(position:) && :set }
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
          joined_via, position = Orm::SchoolStaff.where(user_id:).where.not(archived_at: nil).pick(:joined_via, :position)
          next :not_archived if joined_via.nil?
          next :cap_reached if joined_via == CODE && by_code_count(school_id) >= cap
          next :head_taken if position == HEAD && head_taken?(school_id:)

          guarded do
            Orm::SchoolStaff.where(user_id:).where.not(archived_at: nil).update_all(archived_at: nil, archived_by_id: nil)
            :restored
          end
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

      def locked(school_id)
        Orm::SchoolStaff.transaction do
          lock_school(school_id)
          yield
        end
      end

      def insert(**attributes) = guarded { Orm::SchoolStaff.create!(**attributes) && :attached }

      # Le verrou sérialise les écritures d'un établissement ; l'index partiel du chef unique tranche ce qui lui échapperait
      # (ADR-0092 §4.3). Point de sauvegarde : le refus n'invalide pas la transaction de l'appelant. Tout autre conflit
      # d'unicité (un compte déjà rattaché) remonte tel quel.
      def guarded
        Orm::SchoolStaff.transaction(requires_new: true) { yield }
      rescue ActiveRecord::RecordNotUnique => e
        raise unless e.message.include?(ONE_HEAD_INDEX)

        :head_taken
      end

      def by_code_count(school_id) = Orm::SchoolStaff.active.where(school_id:, joined_via: CODE).count

      def first(scope) = rows(scope.limit(1)).first

      def rows(scope) = scope.joins(:user).pluck(*COLUMNS).map { Entities::School::Staff.new(*it) }
    end
  end
end
