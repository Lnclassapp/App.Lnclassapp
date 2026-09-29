# 🧠 DOMAINE · Ports::School::StaffRepositoryPort
# Rôle : contrat du rattachement d'un compte de direction à son établissement (un seul par compte)
# ADR  : 0065
module Ports
  module School
    module StaffRepositoryPort
      # Écrit dans la transaction de l'acceptation de l'invitation. → true
      def attach(user_id:, school_id:, invited_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach"
      end
    end
  end
end
