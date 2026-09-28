# 🔌 INFRA · Queries::Identity::ProfileQuery
# Rôle : ce que « Mon profil » montre du compte connecté, selon son rôle (lecture seule)
# ADR  : 0055, 0060, 0065, 0066 · UDR : 0041, 0047, 0052, 0053
module Queries
  module Identity
    class ProfileQuery
      # photo_version : nil sans photo (ADR-0060) ; position : fonction d'un membre de la direction rattaché (ADR-0066) ;
      # student_number : matricule de l'élève (ADR-0065), nil pour les autres rôles.
      Row = Data.define(:first_name, :last_name, :contact, :role, :team_role, :classroom_name, :school_name, :material_name,
                        :registered_on, :public_id, :photo_version, :position, :student_number) do
        def display_name = "#{first_name} #{last_name}"
        # « 0701020304 » → « 07 01 02 03 04 », comme on dicte un numéro.
        def grouped_contact = contact.scan(/\d{1,2}/).join(" ")
      end

      COLUMNS = [ :first_name, :last_name, :contact, :role, :team_role, "users.created_at", :public_id, PhotoVersions::CHECKSUM,
                  :student_number ].freeze

      # → Row | nil ; classe principale de l'élève, école principale et matière de l'enseignant, fonction et établissement
      # du rattachement actif d'un membre de la direction, sinon nil
      def call(user_id:)
        first_name, last_name, contact, role, team_role, created_at, public_id, checksum, student_number =
          Orm::User.left_joins(photo_attachment: :blob).where(id: user_id).pick(*COLUMNS)
        return if role.nil?

        position, staff_school_name = (staff_attachment(user_id) if role == "school_admin")
        Row.new(first_name:, last_name:, contact:, role: role.to_sym, team_role:, registered_on: created_at.in_time_zone.to_date,
                public_id:, photo_version: PhotoVersions.of(checksum), position:, student_number:,
                classroom_name: (classroom_name(user_id) if role == "student"),
                school_name: (role == "teacher" ? school_name(user_id) : staff_school_name),
                material_name: (material_name(user_id) if role == "teacher"))
      end

      private

      # Fonction et établissement du rattachement actif, établissement actif (comme UserRepository#actor_for). → [String, String] | nil
      def staff_attachment(user_id)
        Orm::SchoolStaff.active.joins(:school).where(user_id:, schools: { status: "active" }).pick(:position, "schools.name")
      end

      def classroom_name(user_id)
        Orm::ClassroomStudent.joins(:classroom).where(student_id: user_id, primary: true, left_at: nil).pick("classrooms.name")
      end

      def school_name(user_id) = Orm::TeacherSchool.joins(:school).where(teacher_id: user_id, primary: true).pick("schools.name")
      def material_name(user_id) = Orm::TeacherProfile.joins(:material).where(user_id:).pick("materials.name")
    end
  end
end
