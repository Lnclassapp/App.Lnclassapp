# 🔌 INFRA · Repositories::Identity::UserRepository
# Rôle : lit les comptes, vérifie le PIN par bcrypt en temps constant, construit l'acteur
# ADR  : 0026, 0028, 0050
module Repositories
  module Identity
    class UserRepository
      include Ports::Identity::UserRepositoryPort

      def find(id:) = map(Orm::User.find_by(id:))
      def find_by_public_id(public_id:) = map(Orm::User.find_by(public_id:))
      def find_by_contact(contact:) = map(Orm::User.find_by(contact:))

      # authenticate_by hache un PIN factice quand le numéro est inconnu : même durée dans les deux cas.
      def authenticate(contact:, pin:) = map(Orm::User.authenticate_by(contact:, pin:))

      def update_pin(user_id:, pin:)
        Orm::User.find(user_id).update!(pin:)
        true
      end

      def actor_for(user_id:)
        user = Orm::User.find(user_id)
        school_id = Orm::TeacherSchool.where(teacher_id: user_id, primary: true).pick(:school_id)
        Entities::Identity::Actor.new(user_id:, role: user.role.to_sym, team_role: user.team_role, school_id:)
      end

      private

      def map(record)
        return if record.nil?

        Entities::Identity::User.new(
          id: record.id, public_id: record.public_id, last_name: record.last_name, first_name: record.first_name,
          contact: record.contact, gender: record.gender, role: record.role, team_role: record.team_role,
          anonymized_at: record.anonymized_at
        )
      end
    end
  end
end
