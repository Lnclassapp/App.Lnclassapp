# 🧠 DOMAINE · Entities::Identity::AuditRetention
# Rôle : durée de conservation de l'adresse IP du journal d'audit, et taille des lots de son effacement
# ADR  : 0080
module Entities
  module Identity
    module AuditRetention
      IP_MONTHS = 12
      BATCH_SIZE = 1_000
    end
  end
end
