# 🔌 INFRA · Repositories::School::StaffRepository
# Rôle : écrit le rattachement d'un compte de direction à son établissement (table school_staffs)
# ADR  : 0036, 0065
module Repositories
  module School
    class StaffRepository
      include Ports::School::StaffRepositoryPort

      def attach(user_id:, school_id:, invited_by_id:, at:)
        Orm::SchoolStaff.create!(user_id:, school_id:, invited_by_id:, created_at: at)
        true
      end
    end
  end
end
