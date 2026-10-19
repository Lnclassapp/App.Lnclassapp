# 🔌 INFRA · Queries::Identity::ShellUserQuery
# Rôle : ce que le shell affiche de la personne connectée (nom, rôle, détail), lu une fois par requête
# ADR  : 0026, 0060, 0065, 0094 · UDR : 0006, 0047, 0052, 0098
module Queries
  module Identity
    class ShellUserQuery
      # detail : classe active de l'élève (ADR-0088 : une classe archivée n'est plus nommée), matière de l'enseignant, et son
      # établissement courant (UDR-0098 §3.1) ; établissement de la direction (UDR-0052) ;
      # photo_version : nil sans photo (ADR-0060).
      Row = Data.define(:name, :role, :detail, :public_id, :photo_version)

      COLUMNS = [ :first_name, :last_name, :role, :public_id, PhotoVersions::CHECKSUM ].freeze

      # current_school_id : actor.school_id ; pour un enseignant, l'établissement courant s'il y est rattaché, sinon le principal.
      def call(user_id:, current_school_id: nil)
        first_name, last_name, role, public_id, checksum =
          Orm::User.left_joins(photo_attachment: :blob).where(id: user_id).pick(*COLUMNS)
        return if role.nil?

        Row.new(name: "#{first_name} #{last_name}", role: role.to_sym, detail: detail(user_id, role, current_school_id), public_id:,
                photo_version: PhotoVersions.of(checksum))
      end

      private

      def detail(user_id, role, current_school_id)
        parts = case role
        when "student" then student_detail(user_id)
        when "teacher" then teacher_detail(user_id, current_school_id)
        when "school_admin" then Orm::SchoolStaff.joins(:school).where(user_id:).pick("schools.name")
        end
        Array(parts).compact.join(" · ").presence
      end

      def student_detail(user_id)
        Orm::ClassroomStudent.joins(classroom: :school).where(student_id: user_id, primary: true, left_at: nil, classrooms: { status: "active" })
                             .pick("classrooms.name", "schools.name")
      end

      def teacher_detail(user_id, current_school_id)
        material = Orm::TeacherProfile.joins(:material).where(user_id:).pick("materials.name")
        school = Orm::TeacherSchool.joins(:school).where(teacher_id: user_id).current_or_primary(current_school_id).pick("schools.name")
        [ material, school ]
      end
    end
  end
end
