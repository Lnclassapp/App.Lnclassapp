# 🔌 INFRA · Repositories::Identity::UserRepository
# Rôle : lit et modifie les comptes, vérifie le PIN par bcrypt en temps constant, construit l'acteur, anonymise un compte
# ADR  : 0026, 0028, 0036, 0050, 0055, 0065
module Repositories
  module Identity
    class UserRepository
      include Ports::Identity::UserRepositoryPort

      TAKEN = { contact: [ :taken ] }.freeze

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

      # Le secret aléatoire n'est ni rendu ni journalisé : plus personne ne connaît le PIN du compte.
      def anonymize(user_id:, first_name:, last_name:, at:)
        Orm::User.find(user_id).update!(first_name:, last_name:, contact: nil, pin: SecureRandom.base58(32), anonymized_at: at)
        true
      end

      def actor_for(user_id:)
        user = Orm::User.find(user_id)
        Entities::Identity::Actor.new(user_id:, role: user.role.to_sym, team_role: user.team_role, school_id: school_id_of(user))
      end

      private

      # L'école principale d'un enseignant ; le rattachement d'une direction (ADR-0065).
      def school_id_of(user)
        return user.school_staff&.school_id if user.role == "school_admin"

        Orm::TeacherSchool.where(teacher_id: user.id, primary: true).pick(:school_id)
      end

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
