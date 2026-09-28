# 🔌 INFRA · Queries::Identity::ShellUserQuery
# Rôle : ce que le shell affiche de la personne connectée (nom, rôle, détail), lu une fois par requête
# ADR  : 0026, 0060, 0066 · UDR : 0006, 0047, 0052
module Queries
  module Identity
    class ShellUserQuery
      # detail : classe de l'élève, matière de l'enseignant, et son école ; établissement d'un membre de la direction, dont
      # position donne la fonction (le libellé est traduit par le contrôleur) ; photo_version : nil sans photo (ADR-0060).
      Row = Data.define(:name, :role, :detail, :public_id, :photo_version, :position)

      COLUMNS = [ :first_name, :last_name, :role, :public_id, PhotoVersions::CHECKSUM ].freeze

      def call(user_id:)
        first_name, last_name, role, public_id, checksum =
          Orm::User.left_joins(photo_attachment: :blob).where(id: user_id).pick(*COLUMNS)
        return if role.nil?

        position, school_name = (staff_attachment(user_id) if role == "school_admin")
        Row.new(name: "#{first_name} #{last_name}", role: role.to_sym, detail: school_name || detail(user_id, role), public_id:,
                photo_version: PhotoVersions.of(checksum), position:)
      end

      private

      # Fonction et établissement du rattachement actif, établissement actif (comme UserRepository#actor_for). → [String, String] | nil
      def staff_attachment(user_id)
        Orm::SchoolStaff.active.joins(:school).where(user_id:, schools: { status: "active" }).pick(:position, "schools.name")
      end

      def detail(user_id, role)
        parts = case role
        when "student" then student_detail(user_id)
        when "teacher" then teacher_detail(user_id)
        end
        Array(parts).compact.join(" · ").presence
      end

      def student_detail(user_id)
        Orm::ClassroomStudent.joins(classroom: :school).where(student_id: user_id, primary: true, left_at: nil)
                             .pick("classrooms.name", "schools.name")
      end

      def teacher_detail(user_id)
        material = Orm::TeacherProfile.joins(:material).where(user_id:).pick("materials.name")
        school = Orm::TeacherSchool.joins(:school).where(teacher_id: user_id, primary: true).pick("schools.name")
        [ material, school ]
      end
    end
  end
end
