# 🔌 INFRA · Queries::Identity::ShellUserQuery
# Rôle : ce que le shell affiche de la personne connectée (nom, rôle, détail), lu une fois par requête
# ADR  : 0026 · UDR : 0006
module Queries
  module Identity
    class ShellUserQuery
      # Compatible avec NavigationHelper::ShellUser ; detail : classe de l'élève, matière de l'enseignant, et son école.
      Row = Data.define(:name, :role, :detail)

      def call(user_id:)
        first_name, last_name, role = Orm::User.where(id: user_id).pick(:first_name, :last_name, :role)
        return if role.nil?

        Row.new(name: "#{first_name} #{last_name}", role: role.to_sym, detail: detail(user_id, role))
      end

      private

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
