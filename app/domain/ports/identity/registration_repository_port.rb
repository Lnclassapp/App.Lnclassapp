# 🧠 DOMAINE · Ports::Identity::RegistrationRepositoryPort
# Rôle : contrat de création des comptes ; appelé dans la transaction du use case
# ADR  : 0026, 0030, 0038, 0050, 0065
module Ports
  module Identity
    module RegistrationRepositoryPort
      # user : Entities::Identity::User sans id, avec son student_number (ADR-0065, écrit à partir du Lot F).
      # → Result(User) | failure(:conflict, errors: { contact: [:taken] } ou { student_number: [:taken] })
      def create_student(user:, pin:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_student"
      end

      # Crée aussi la ligne teacher_profiles. → Result(User) | failure(:conflict, …)
      def create_teacher(user:, pin:, material_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_teacher"
      end

      # Pose aussi accepted_at et accepted_user_id sur l'invitation. → Result(User) | failure(:conflict, …)
      def create_from_invitation(user:, pin:, invitation_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_from_invitation"
      end
    end
  end
end
