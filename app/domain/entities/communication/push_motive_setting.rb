# 🧠 DOMAINE · Entities::Communication::PushMotiveSetting
# Rôle : le réglage d'un motif : sa case (cochée, il part ; décochée, rien ne part), qui l'a posée et quand
# ADR  : XXXX envois de notifications (§4.1)
module Entities
  module Communication
    PushMotiveSetting = Data.define(:motive, :automatic, :updated_by_id, :updated_at) do
      # Un motif inconnu lève, il ne passe pas en silence.
      def initialize(motive:, automatic:, updated_by_id:, updated_at:)
        raise ArgumentError, "motif non automatisable : #{motive.inspect}" unless PushMotive.automatable?(motive)

        super
      end
    end
  end
end
