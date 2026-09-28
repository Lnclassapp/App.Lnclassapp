# 🧠 DOMAINE · Entities::School::StaffMember
# Rôle : rattachement d'un compte de la direction à un établissement, avec sa fonction ; actif tant que left_at est nul
# ADR  : 0044, 0066
module Entities
  module School
    StaffMember = Data.define(:id, :user_id, :school_id, :position, :invited_by_id, :joined_at, :left_at) do
      def active? = left_at.nil?
      def principal? = position == "principal"
    end
  end
end
