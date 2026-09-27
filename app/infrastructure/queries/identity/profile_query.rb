# 🔌 INFRA · Queries::Identity::ProfileQuery
# Rôle : ce que « Mon profil » montre du compte connecté, selon son rôle (lecture seule)
# ADR  : 0055 · UDR : 0041
module Queries
  module Identity
    class ProfileQuery
      Row = Data.define(:first_name, :last_name, :contact, :role, :team_role, :classroom_name, :school_name, :material_name,
                        :registered_on) do
        def display_name = "#{first_name} #{last_name}"
        # « 0701020304 » → « 07 01 02 03 04 », comme on dicte un numéro.
        def grouped_contact = contact.scan(/\d{1,2}/).join(" ")
      end

      COLUMNS = %i[first_name last_name contact role team_role created_at].freeze

      # → Row | nil ; classe principale de l'élève, école principale et matière de l'enseignant, sinon nil
      def call(user_id:)
        first_name, last_name, contact, role, team_role, created_at = Orm::User.where(id: user_id).pick(*COLUMNS)
        return if role.nil?

        Row.new(first_name:, last_name:, contact:, role: role.to_sym, team_role:, registered_on: created_at.in_time_zone.to_date,
                classroom_name: (classroom_name(user_id) if role == "student"),
                school_name: (school_name(user_id) if role == "teacher"),
                material_name: (material_name(user_id) if role == "teacher"))
      end

      private

      def classroom_name(user_id)
        Orm::ClassroomStudent.joins(:classroom).where(student_id: user_id, primary: true, left_at: nil).pick("classrooms.name")
      end

      def school_name(user_id) = Orm::TeacherSchool.joins(:school).where(teacher_id: user_id, primary: true).pick("schools.name")
      def material_name(user_id) = Orm::TeacherProfile.joins(:material).where(user_id:).pick("materials.name")
    end
  end
end
