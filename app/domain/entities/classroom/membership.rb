# 🧠 DOMAINE · Entities::Classroom::Membership
# Rôle : adhésion d'un élève à une classe, avec le statut de la classe
# ADR  : 0040, 0041
module Entities
  module Classroom
    Membership = Data.define(:classroom_id, :student_id, :primary, :joined_at, :left_at, :classroom_status) do
      def active? = left_at.nil?
      def classroom_active? = classroom_status == "active"
    end
  end
end
