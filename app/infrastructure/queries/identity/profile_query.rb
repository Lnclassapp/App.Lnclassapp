# 🔌 INFRA · Queries::Identity::ProfileQuery
# Rôle : ce que « Mon profil » montre du compte connecté, selon son rôle (lecture seule)
# ADR  : 0055, 0060 · UDR : 0041, 0047
module Queries
  module Identity
    class ProfileQuery
      # photo_version : nil sans photo (ADR-0060).
      Row = Data.define(:first_name, :last_name, :contact, :role, :team_role, :classroom_name, :school_name, :material_name,
                        :registered_on, :public_id, :photo_version) do
        def display_name = "#{first_name} #{last_name}"
        # « 0701020304 » → « 07 01 02 03 04 », comme on dicte un numéro.
        def grouped_contact = contact.scan(/\d{1,2}/).join(" ")
      end

      COLUMNS = [ :first_name, :last_name, :contact, :role, :team_role, "users.created_at", :public_id, PhotoVersions::CHECKSUM ].freeze

      # → Row | nil ; classe principale de l'élève, école principale et matière de l'enseignant, sinon nil
      def call(user_id:)
        first_name, last_name, contact, role, team_role, created_at, public_id, checksum =
          Orm::User.left_joins(photo_attachment: :blob).where(id: user_id).pick(*COLUMNS)
        return if role.nil?

        Row.new(first_name:, last_name:, contact:, role: role.to_sym, team_role:, registered_on: created_at.in_time_zone.to_date,
                public_id:, photo_version: PhotoVersions.of(checksum),
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
