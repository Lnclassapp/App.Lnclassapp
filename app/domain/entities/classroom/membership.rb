# 🧠 DOMAINE · Entities::Classroom::Membership
# Rôle : adhésion d'un élève à une classe, avec le statut de la classe
# ADR  : 0040, 0041, 0083
module Entities
  module Classroom
    Membership = Data.define(:classroom_id, :student_id, :primary, :joined_at, :left_at, :classroom_status, :joined_via,
                             :removed_at) do
      # joined_via, removed_at : nil pour qui ne les lit pas (ADR-0083 §4.4, §4.5).
      def initialize(joined_via: nil, removed_at: nil, **rest) = super

      def active? = left_at.nil?
      def classroom_active? = classroom_status == "active"
      def removed? = !removed_at.nil?
    end
  end
end
