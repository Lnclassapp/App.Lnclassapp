# 🔌 INFRA · Repositories::Identity::UserRepository
# Rôle : lit et modifie les comptes, vérifie le PIN par bcrypt en temps constant, construit l'acteur, anonymise un compte
# ADR  : 0026, 0028, 0036, 0050, 0055, 0065, 0077, 0082
module Repositories
  module Identity
    class UserRepository
      include Ports::Identity::UserRepositoryPort

      TAKEN = { contact: [ :taken ] }.freeze

      def find(id:) = map(Orm::User.find_by(id:))
      def find_by_public_id(public_id:) = map(Orm::User.find_by(public_id:))
      def find_by_contact(contact:) = map(Orm::User.find_by(contact:))

      # authenticate_by hache un PIN factice quand le numéro est inconnu : même durée dans les deux cas.
      # Une direction archivée reçoit le refus d'un mauvais PIN : le compte n'est pas révélé (ADR-0077 §4.2).
      def authenticate(contact:, pin:)
        user = Orm::User.authenticate_by(contact:, pin:)
        map(user) unless user && archived_school_admin?(user)
      end

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

      # ADR-0082 §4.3 : une seule colonne, sans toucher updated_at (ce n'est pas une modification du compte).
      def mark_app_opened(user_id:, at:)
        Orm::User.where(id: user_id).update_all(app_opened_at: at)
        true
      end

      def actor_for(user_id:)
        user = Orm::User.find(user_id)
        Entities::Identity::Actor.new(user_id:, role: user.role.to_sym, team_role: user.team_role, school_id: school_id_of(user))
      end

      private

      # L'école principale d'un enseignant ; le rattachement actif d'une direction (ADR-0065) : archivée, elle n'en a
      # aucun et une session survivante la mène à l'écran d'attente (ADR-0077 §4.2).
      def school_id_of(user)
        return Orm::SchoolStaff.active.where(user_id: user.id).pick(:school_id) if user.role == "school_admin"

        Orm::TeacherSchool.where(teacher_id: user.id, primary: true).pick(:school_id)
      end

      def archived_school_admin?(user)
        user.role == "school_admin" && Orm::SchoolStaff.where(user_id: user.id).where.not(archived_at: nil).exists?
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
