# 🔌 INFRA · Queries::School::JoinRequestsQuery
# Rôle : demandes en attente, lues par l'équipe (fiche, avec le numéro), par un collègue actif (accueil, sans numéro), et leur état
# ADR  : 0028, 0063 · UDR : 0050
module Queries
  module School
    class JoinRequestsQuery
      TeamRow = Data.define(:public_id, :name, :contact, :material_name, :material_category, :created_at)
      ColleagueRow = Data.define(:public_id, :name, :material_name, :material_category, :created_at)
      Colleagues = Data.define(:school_name, :requests)
      Status = Data.define(:school_name, :status)

      PENDING = "pending".freeze
      FULL_NAME = Arel.sql("users.first_name || ' ' || users.last_name")
      COLUMNS = [ "school_join_requests.public_id", FULL_NAME, "materials.name", "materials.category",
                  "school_join_requests.created_at" ].freeze

      # → [TeamRow], la plus ancienne d'abord
      def for_school(school_public_id:)
        pending.joins(:school).where(schools: { public_id: school_public_id })
               .pluck(*COLUMNS.dup.insert(2, "users.contact")).map { TeamRow.new(*it) }
      end

      # Demandes de l'école principale d'un enseignant ; nil sans école ou sans demande. → Colleagues | nil
      def for_colleague(teacher_id:)
        school_id, school_name = Orm::TeacherSchool.joins(:school).where(teacher_id:, primary: true).pick(:school_id, "schools.name")
        return if school_id.nil?

        requests = pending.where(school_id:).where.not(teacher_id:).pluck(*COLUMNS).map { ColleagueRow.new(*it) }
        Colleagues.new(school_name:, requests:) if requests.any?
      end

      # → Status | nil (enseignant sans demande)
      def status_for(teacher_id:)
        values = Orm::SchoolJoinRequest.joins(:school).where(teacher_id:).pick("schools.name", :status)
        values && Status.new(*values)
      end

      private

      def pending
        Orm::SchoolJoinRequest.joins(:teacher)
                              .joins("LEFT JOIN teacher_profiles ON teacher_profiles.user_id = school_join_requests.teacher_id")
                              .joins("LEFT JOIN materials ON materials.id = teacher_profiles.material_id")
                              .where(status: PENDING).order("school_join_requests.created_at", "school_join_requests.id")
      end
    end
  end
end
