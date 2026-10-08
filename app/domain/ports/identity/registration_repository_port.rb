# 🧠 DOMAINE · Ports::Identity::RegistrationRepositoryPort
# Rôle : contrat de création des comptes ; appelé dans la transaction du use case
# ADR  : 0026, 0030, 0038, 0050, 0077, 0083
module Ports
  module Identity
    module RegistrationRepositoryPort
      # user : Entities::Identity::User sans id
      # → Result(User) | failure(:conflict, errors: { contact: [:taken] })
      def create_student(user:, pin:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_student"
      end

      # Crée aussi la ligne teacher_profiles, avec sa voie d'arrivée. joined_via ∈ Entities::Identity::ArrivalChannel::ALL
      # (ADR-0083 §4.2). → Result(User) | failure(:conflict, …)
      def create_teacher(user:, pin:, material_id:, joined_via:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_teacher"
      end

      # ADR-0077 : la direction inscrite avec le code d'établissement, sans invitation ; son rattachement est écrit à part
      # (StaffRepositoryPort#attach_by_code). → Result(User) | failure(:conflict, …)
      def create_school_admin(user:, pin:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_school_admin"
      end

      # Pose aussi accepted_at et accepted_user_id sur l'invitation. → Result(User) | failure(:conflict, …)
      def create_from_invitation(user:, pin:, invitation_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_from_invitation"
      end
    end
  end
end
