# 🌐 DELIVERY · Teams::Crm::HomeFollowUpsController
# Rôle : carte « À relancer » de l'Accueil équipe : mes écoles à relancer (garde ManageCrmPolicy héritée), servie dans un frame paresseux
# ADR  : XXXX (contexte crm) · UDR : XXXX (pipeline et relances)
module Teams
  module Crm
    class HomeFollowUpsController < BaseController
      SHOWN = 3

      def show
        page = Queries::Crm::FollowUpSignalsQuery.new.mine(user_id: current_actor.user_id)
        @count = page.total_count
        @rows = page.rows.first(SHOWN)
      end
    end
  end
end
