# 🔌 INFRA · Orm::Communication::PushMotiveSettingChange
# Rôle : table push_motive_setting_changes : l'historique des réglages (qui a coché ou décoché quoi, quand) ; jamais modifié, gardé 90 jours
# ADR  : XXXX envois de notifications (§4.1)
module Orm
  module Communication
    class PushMotiveSettingChange < ApplicationRecord
      self.table_name = "push_motive_setting_changes"

      belongs_to :changed_by, class_name: "Orm::User"

      validates :motive, :changed_at, presence: true
    end
  end
end
