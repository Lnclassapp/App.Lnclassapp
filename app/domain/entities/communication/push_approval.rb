# 🧠 DOMAINE · Entities::Communication::PushApproval
# Rôle : la validation par l'équipe d'un motif pour un jour d'Abidjan : qui, quand, combien d'élèves (la liste est figée à part)
# ADR  : XXXX envois de notifications (§4.1, §4.4)
module Entities
  module Communication
    PushApproval = Data.define(:id, :on_date, :motive, :approved_by_id, :approved_at, :recipients_count) do
      def initialize(on_date:, motive:, approved_by_id:, approved_at:, recipients_count:, id: nil)
        raise ArgumentError, "motif non validable : #{motive.inspect}" unless PushMotive::PLANNABLE.include?(motive)

        super
      end
    end
  end
end
