# 🧠 DOMAINE · Entities::Communication::PushMotiveSetting
# Rôle : le réglage d'un motif automatisable : la case « Automatique », qui l'a posée et quand
# ADR  : XXXX envois de notifications (§4.1)
module Entities
  module Communication
    PushMotiveSetting = Data.define(:motive, :automatic, :updated_by_id, :updated_at) do
      # Une relance ne devient jamais automatique : un motif hors AUTOMATABLE lève, il ne passe pas en silence.
      def initialize(motive:, automatic:, updated_by_id:, updated_at:)
        raise ArgumentError, "motif non automatisable : #{motive.inspect}" unless PushMotive.automatable?(motive)

        super
      end
    end
  end
end
