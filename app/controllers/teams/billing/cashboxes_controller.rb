# 🌐 DELIVERY · Teams::Billing::CashboxesController
# Rôle : la caisse de l'équipe : à payer ce vendredi, dû par point relais, commissions cumulées des écoles
# ADR  : 0126 (contexte billing, §4.7) · UDR : 0159 §3.1
module Teams
  module Billing
    class CashboxesController < Teams::BaseController
      def show
        @cashbox = Queries::Billing::CashboxQuery.new.call(at: Time.current)
      end
    end
  end
end
