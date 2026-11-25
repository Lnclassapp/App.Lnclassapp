# 🔌 INFRA · Orm::Communication::PushPreference
# Rôle : table push_preferences : l'interrupteur de l'élève (coupé) et le report de la carte d'invitation
# ADR  : 0146 (§4.1)
module Orm
  module Communication
    class PushPreference < ApplicationRecord
      self.table_name = "push_preferences"

      belongs_to :user, class_name: "Orm::User"

      validates :user_id, uniqueness: true
    end
  end
end
