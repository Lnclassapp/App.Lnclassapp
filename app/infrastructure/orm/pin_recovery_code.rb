# 🔌 INFRA · Orm::PinRecoveryCode
# Rôle : table pin_recovery_codes, code de récupération du PIN (empreinte HMAC seulement)
# ADR  : 0032
module Orm
  class PinRecoveryCode < ApplicationRecord
    self.table_name = "pin_recovery_codes"

    belongs_to :user, class_name: "Orm::User"
    belongs_to :issued_by, class_name: "Orm::User"
  end
end
