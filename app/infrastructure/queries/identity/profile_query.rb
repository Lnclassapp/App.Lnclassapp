# 🔌 INFRA · Queries::Identity::ProfileQuery
# Rôle : ce que « Mon profil » montre du compte connecté, selon son rôle (lecture seule)
# ADR  : 0055, 0060, 0065, 0094, 0103 · UDR : 0041, 0047, 0052, 0089 (établissement de l'élève), 0125 (matières)
module Queries
  module Identity
    class ProfileQuery
      # photo_version : nil sans photo (ADR-0060). materials : [TeacherMaterialsQuery::MaterialTag] de l'enseignant dans
      # l'établissement affiché (ADR-0103), dans l'ordre ; [] pour les autres rôles.
      Row = Data.define(:first_name, :last_name, :contact, :role, :team_role, :classroom_name, :school_name, :materials,
                        :registered_on, :public_id, :photo_version) do
        def display_name = "#{first_name} #{last_name}"
        # « 0701020304 » → « 07 01 02 03 04 », comme on dicte un numéro.
        def grouped_contact = contact.scan(/\d{1,2}/).join(" ")
      end

      COLUMNS = [ :first_name, :last_name, :contact, :role, :team_role, "users.created_at", :public_id, PhotoVersions::CHECKSUM ].freeze

      # → Row | nil ; classe principale active de l'élève et son établissement (UDR-0089), école principale et matière de
      # l'enseignant (son établissement courant, current_school_id = actor.school_id, ADR-0094 §4.6), établissement de la
      # direction, sinon nil
      def call(user_id:, current_school_id: nil)
        first_name, last_name, contact, role, team_role, created_at, public_id, checksum =
          Orm::User.left_joins(photo_attachment: :blob).where(id: user_id).pick(*COLUMNS)
        return if role.nil?

        classroom_name, school_name, school_id = role == "student" ? student_classroom(user_id) : school(user_id, role, current_school_id)
        Row.new(first_name:, last_name:, contact:, role: role.to_sym, team_role:, registered_on: created_at.in_time_zone.to_date,
                public_id:, photo_version: PhotoVersions.of(checksum),
                classroom_name:, school_name:, materials: (role == "teacher" ? materials(user_id, school_id) : []))
      end

      private

      # → [classe, établissement], ou [nil, nil] sans classe principale active
      def student_classroom(user_id)
        Orm::ClassroomStudent.joins(classroom: :school).where(student_id: user_id, primary: true, left_at: nil)
                             .pick("classrooms.name", "schools.name") || [ nil, nil ]
      end

      # → [nil, nom de l'établissement, son id]
      def school(user_id, role, current_school_id)
        name, id = case role
        when "teacher"
          Orm::TeacherSchool.joins(:school).where(teacher_id: user_id).current_or_primary(current_school_id).pick("schools.name", "schools.id")
        when "school_admin" then Orm::SchoolStaff.joins(:school).where(user_id:).pick("schools.name", "schools.id")
        end
        [ nil, name, id ]
      end

      # ADR-0103 : ses matières de l'établissement affiché, celles que « Mes matières » modifie.
      def materials(user_id, school_id)
        return [] if school_id.nil?

        TeacherMaterialsQuery.new.tags_for(teacher_ids: [ user_id ], school_id:).fetch(user_id)
      end
    end
  end
end
