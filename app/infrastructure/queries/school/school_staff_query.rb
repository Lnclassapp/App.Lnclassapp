# 🔌 INFRA · Queries::School::SchoolStaffQuery
# Rôle : les comptes direction d'un établissement (bloc « Direction », bandeau d'arrivée) et les directions retirées (équipe)
# ADR  : 0065, 0077 · UDR : 0070 · une requête par lecture, quel que soit le volume
module Queries
  module School
    class SchoolStaffQuery
      Row = Data.define(:user_id, :public_id, :name, :joined_via, :joined_at)
      # gender : accorde « retiré » ou « retirée » (suites-inscription-direction).
      ArchivedRow = Data.define(:public_id, :name, :school_public_id, :school_name, :archived_by_name, :archived_at, :joined_via,
                                :gender) do
        def deletion_due_at = archived_at + Entities::School::Staff::RETENTION_DAYS.days
      end

      CODE = "code".freeze
      FULL_NAME = Arel.sql("users.first_name || ' ' || users.last_name")
      AUTHOR_NAME = Arel.sql("authors.first_name || ' ' || authors.last_name")
      ROW = [ "school_staffs.user_id", "users.public_id", FULL_NAME, "school_staffs.joined_via", "school_staffs.created_at" ].freeze

      # Les directions actives, de la plus ancienne à la plus récente.
      def active_for(school_id:) = rows(active(school_id).order("school_staffs.created_at", "school_staffs.id"))

      # Le nombre de directions actives arrivées par le code (le « 2 / 3 » du bloc).
      def by_code_count(school_id:) = active(school_id).where(joined_via: CODE).count

      # Bandeau d'arrivée : les arrivées depuis `since`, sauf la personne qui lit, la plus récente d'abord, au plus `limit`.
      def recent_arrivals(school_id:, since:, except_user_id:, limit: 3)
        rows(active(school_id).where(created_at: since..).where.not(user_id: except_user_id)
                              .order("school_staffs.created_at DESC", "school_staffs.id DESC").limit(limit))
      end

      # Les directions retirées, la plus récente d'abord ; tous établissements si school_id est nil.
      def archived(school_id: nil)
        scope = Orm::SchoolStaff.where.not(archived_at: nil).joins(:user, :school)
                                .joins("JOIN users authors ON authors.id = school_staffs.archived_by_id")
        scope = scope.where(school_id:) if school_id
        scope.order(archived_at: :desc, id: :desc)
             .pluck("users.public_id", FULL_NAME, "schools.public_id", "schools.name", AUTHOR_NAME, :archived_at, :joined_via,
                    "users.gender")
             .map { ArchivedRow.new(*it) }
      end

      private

      def active(school_id) = Orm::SchoolStaff.active.joins(:user).where(school_id:)

      def rows(scope) = scope.pluck(*ROW).map { Row.new(*it) }
    end
  end
end
