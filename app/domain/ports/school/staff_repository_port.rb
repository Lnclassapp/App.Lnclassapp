# 🧠 DOMAINE · Ports::School::StaffRepositoryPort
# Rôle : contrat des rattachements de la direction (school_staffs) : un établissement actif par membre, un Proviseur actif
# ADR  : 0044, 0066
module Ports
  module School
    module StaffRepositoryPort
      # Dans la transaction de l'appelant ; les deux index uniques partiels tranchent sous concurrence.
      # → Result(Entities::School::StaffMember) | failure(:conflict, errors: { base: [:other_school] })
      #   | failure(:conflict, errors: { position: [:principal_taken] }) ; ArgumentError si le compte n'est pas school_admin
      def attach(user_id:, school_id:, position:, invited_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach"
      end

      # Rattachement actif (left_at nul) du compte à cet établissement. → Entities::School::StaffMember | nil
      def find_active(user_public_id:, school_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_active"
      end

      # → Boolean
      def principal_active?(school_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #principal_active?"
      end

      # Pose left_at. → true
      def detach(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #detach"
      end
    end
  end
end
