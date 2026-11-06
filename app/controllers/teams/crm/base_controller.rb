# 🌐 DELIVERY · Teams::Crm::BaseController
# Rôle : parent des contrôleurs du suivi des écoles ; `admin` et `field` seuls (ManageCrmPolicy), 403 pour tout autre rôle
# ADR  : XXXX (contexte crm), 0028, 0038
module Teams
  module Crm
    class BaseController < Teams::BaseController
      before_action { render_forbidden if Policies::Crm::ManageCrmPolicy.new.call(actor: current_actor).failure? }
    end
  end
end
