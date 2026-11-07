# 🌐 DELIVERY · Teams::Billing::CashboxesController
# Rôle : la caisse de l'équipe : à payer ce vendredi, dû par point relais, commissions cumulées des écoles
# ADR  : cartes-activation (contexte billing, §4.7) · UDR : caisse-equipe §3.1
module Teams
  module Billing
    class CashboxesController < Teams::BaseController
      def show
        @cashbox = Queries::Billing::CashboxQuery.new.call(at: Time.current)
      end
    end
  end
end
