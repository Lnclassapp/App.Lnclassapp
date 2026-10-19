# 🔌 INFRA · Queries::Identity::ShellUserQuery
# Rôle : ce que le shell affiche de la personne connectée (nom, rôle, détail, et ses éléments pour le message WhatsApp), lu une fois par requête
# ADR  : 0026, 0060, 0065, 0094 · UDR : 0006, 0047, 0052, 0098, 0128
module Queries
  module Identity
    class ShellUserQuery
      # detail : classe active de l'élève (ADR-0088 : une classe archivée n'est plus nommée), matière de l'enseignant, et son
      # établissement courant (UDR-0098 §3.1) ; établissement de la direction (UDR-0052) ;
      # photo_version : nil sans photo (ADR-0060) ; about : les mêmes éléments, séparés, et le genre (UDR-0128).
      Row = Data.define(:name, :role, :detail, :public_id, :photo_version, :about)
      # UDR-0128 §3.1 : le message prêt de la carte d'aide nomme chaque élément ; gender accorde « enseignant(e) ».
      About = Data.define(:gender, :classroom, :material, :school) do
        def initialize(gender:, classroom: nil, material: nil, school: nil) = super

        def detail = [ classroom, material, school ].compact.join(" · ").presence
      end

      COLUMNS = [ :first_name, :last_name, :role, :gender, :public_id, PhotoVersions::CHECKSUM ].freeze

      # current_school_id : actor.school_id ; pour un enseignant, l'établissement courant s'il y est rattaché, sinon le principal.
      def call(user_id:, current_school_id: nil)
        first_name, last_name, role, gender, public_id, checksum =
          Orm::User.left_joins(photo_attachment: :blob).where(id: user_id).pick(*COLUMNS)
        return if role.nil?

        about = about(user_id, role, gender, current_school_id)
        Row.new(name: "#{first_name} #{last_name}", role: role.to_sym, detail: about.detail, public_id:,
                photo_version: PhotoVersions.of(checksum), about:)
      end

      private

      def about(user_id, role, gender, current_school_id)
        case role
        when "student" then student_about(user_id, gender)
        when "teacher" then teacher_about(user_id, gender, current_school_id)
        when "school_admin"
          About.new(gender:, school: Orm::SchoolStaff.joins(:school).where(user_id:).pick("schools.name"))
        else About.new(gender:)
        end
      end

      def student_about(user_id, gender)
        classroom, school =
          Orm::ClassroomStudent.joins(classroom: :school).where(student_id: user_id, primary: true, left_at: nil, classrooms: { status: "active" })
                               .pick("classrooms.name", "schools.name")
        About.new(gender:, classroom:, school:)
      end

      def teacher_about(user_id, gender, current_school_id)
        material = Orm::TeacherProfile.joins(:material).where(user_id:).pick("materials.name")
        school = Orm::TeacherSchool.joins(:school).where(teacher_id: user_id).current_or_primary(current_school_id).pick("schools.name")
        About.new(gender:, material:, school:)
      end
    end
  end
end
