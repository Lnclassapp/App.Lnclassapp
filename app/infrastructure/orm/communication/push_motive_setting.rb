# 🔌 INFRA · Orm::Communication::PushMotiveSetting
# Rôle : table push_motive_settings : la case « Automatique » d'un motif (une ligne par motif ; absence = décoché)
# ADR  : XXXX envois de notifications (§4.1)
module Orm
  module Communication
    class PushMotiveSetting < ApplicationRecord
      self.table_name = "push_motive_settings"

      belongs_to :updated_by, class_name: "Orm::User"

      validates :motive, :updated_at, presence: true
    end
  end
end
