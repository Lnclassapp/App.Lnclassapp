# 🔌 INFRA · Repositories::Identity::UserRepository
# Rôle : lit et modifie les comptes et le matricule, vérifie le PIN par bcrypt en temps constant, construit l'acteur
# ADR  : 0026, 0028, 0050, 0055, 0065, 0066
module Repositories
  module Identity
    class UserRepository
      include Ports::Identity::UserRepositoryPort

      TAKEN = { contact: [ :taken ] }.freeze
      STUDENT_NUMBER_TAKEN = { student_number: [ :taken ] }.freeze

      def find(id:) = map(Orm::User.find_by(id:))
      def find_by_public_id(public_id:) = map(Orm::User.find_by(public_id:))
      def find_by_contact(contact:) = map(Orm::User.find_by(contact:))

      # authenticate_by hache un PIN factice quand le numéro est inconnu : même durée dans les deux cas.
      def authenticate(contact:, pin:) = map(Orm::User.authenticate_by(contact:, pin:))

      def update_pin(user_id:, pin:)
        Orm::User.find(user_id).update!(pin:)
        true
      end

      def update_name(user_id:, first_name:, last_name:)
        Orm::User.find(user_id).update!(first_name:, last_name:)
        true
      end

      # Point de sauvegarde : l'index unique refusé n'invalide pas la transaction du use case.
      def update_contact(user_id:, contact:)
        Orm::User.transaction(requires_new: true) { Orm::User.find(user_id).update!(contact:) }
        ::Shared::Result.success
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: TAKEN)
      end

      def actor_for(user_id:)
        user = Orm::User.find(user_id)
        school_id, position = user.role == "school_admin" ? staff_of(user_id) : [ primary_school_of(user_id), nil ]
        Entities::Identity::Actor.new(user_id:, role: user.role.to_sym, team_role: user.team_role, school_id:, position:)
      end

      # Égalité stricte, élèves non anonymisés seulement : aucune recherche partielle (ADR-0065).
      def find_student_by_number(student_number:)
        map(Orm::User.find_by(role: "student", anonymized_at: nil, student_number: student_number.to_s))
      end

      # Point de sauvegarde : l'index unique refusé n'invalide pas la transaction du use case.
      def update_student_number(user_id:, student_number:)
        Orm::User.transaction(requires_new: true) { Orm::User.find(user_id).update!(student_number:) }
        ::Shared::Result.success
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: STUDENT_NUMBER_TAKEN)
      end

      private

      def primary_school_of(user_id) = Orm::TeacherSchool.where(teacher_id: user_id, primary: true).pick(:school_id)

      # Rattachement actif à un établissement actif ; sinon ni établissement ni fonction (ADR-0066 §4.1).
      def staff_of(user_id)
        Orm::SchoolStaff.active.joins(:school).where(user_id:, schools: { status: "active" })
                        .pick(:school_id, :position) || [ nil, nil ]
      end

      def map(record)
        return if record.nil?

        Entities::Identity::User.new(
          id: record.id, public_id: record.public_id, last_name: record.last_name, first_name: record.first_name,
          contact: record.contact, gender: record.gender, role: record.role, team_role: record.team_role,
          anonymized_at: record.anonymized_at, student_number: record.student_number
        )
      end
    end
  end
end
