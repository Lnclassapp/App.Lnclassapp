# 🧠 DOMAINE · Entities::Classroom::Membership
# Rôle : adhésion d'un élève à une classe, avec le statut, l'établissement, l'année et le nom de la classe
# ADR  : 0040, 0041, 0066
module Entities
  module Classroom
    # Les quatre derniers champs sont lus avec la classe (MembershipRepositoryPort#primary_for) ; nil par défaut, pour les
    # appelants qui n'en ont pas besoin.
    Membership = Data.define(:classroom_id, :student_id, :primary, :joined_at, :left_at, :classroom_status,
                             :school_id, :school_year, :classroom_public_id, :classroom_name) do
      def initialize(classroom_id:, student_id:, primary:, joined_at:, left_at:, classroom_status:, school_id: nil,
                     school_year: nil, classroom_public_id: nil, classroom_name: nil)
        super
      end

      def active? = left_at.nil?
      def classroom_active? = classroom_status == "active"
    end
  end
end
