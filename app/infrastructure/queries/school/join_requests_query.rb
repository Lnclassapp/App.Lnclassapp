# 🔌 INFRA · Queries::School::JoinRequestsQuery
# Rôle : demandes en attente, lues par l'équipe (fiche, avec le numéro), par un collègue actif (accueil, sans numéro), et leur état
# ADR  : 0028, 0063, 0094, 0103 · UDR : 0050, 0127 (§3.5)
module Queries
  module School
    class JoinRequestsQuery
      # materials : toutes les listes du demandeur, sans doublon (il n'a aucun rattachement, ADR-0103 §4.3).
      TeamRow = Data.define(:public_id, :name, :contact, :materials, :created_at)
      ColleagueRow = Data.define(:public_id, :name, :materials, :created_at)
      Colleagues = Data.define(:school_name, :requests)
      Status = Data.define(:school_name, :status)

      PENDING = "pending".freeze
      FULL_NAME = Arel.sql("users.first_name || ' ' || users.last_name")
      COLUMNS = [ "school_join_requests.public_id", FULL_NAME,
                  Queries::Identity::TeacherMaterialsQuery.column(:school_join_requests),
                  "school_join_requests.created_at" ].freeze

      # → [TeamRow], la plus ancienne d'abord
      def for_school(school_public_id:)
        pending.joins(:school).where(schools: { public_id: school_public_id }).pluck(*COLUMNS, "users.contact")
               .map do |public_id, name, tags, created_at, contact|
                 TeamRow.new(public_id:, name:, contact:, materials: Queries::Identity::TeacherMaterialsQuery.from_json(tags), created_at:)
               end
      end

      # Demandes de l'établissement courant d'un enseignant (school_id = actor.school_id, ADR-0094) ; nil s'il n'y est pas
      # rattaché ou sans demande. → Colleagues | nil
      def for_colleague(teacher_id:, school_id:)
        school_name = Orm::TeacherSchool.joins(:school).where(teacher_id:, school_id:).pick("schools.name")
        return if school_name.nil?

        requests = pending.where(school_id:).where.not(teacher_id:).pluck(*COLUMNS).map do |public_id, name, tags, created_at|
          ColleagueRow.new(public_id:, name:, materials: Queries::Identity::TeacherMaterialsQuery.from_json(tags), created_at:)
        end
        Colleagues.new(school_name:, requests:) if requests.any?
      end

      # La demande appartient-elle à l'établissement de l'URL ? (m3) → Boolean
      def in_school?(public_id:, school_public_id:)
        Orm::SchoolJoinRequest.joins(:school).exists?(public_id:, schools: { public_id: school_public_id })
      end

      # → Status | nil (enseignant sans demande)
      def status_for(teacher_id:)
        values = Orm::SchoolJoinRequest.joins(:school).where(teacher_id:).pick("schools.name", :status)
        values && Status.new(*values)
      end

      private

      def pending
        Orm::SchoolJoinRequest.joins(:teacher)
                              .where(status: PENDING).order("school_join_requests.created_at", "school_join_requests.id")
      end
    end
  end
end
