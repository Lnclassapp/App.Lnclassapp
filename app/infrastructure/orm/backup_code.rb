# 🔌 INFRA · Orm::BackupCode
# Rôle : table backup_codes, codes de secours à usage unique (empreinte HMAC seulement)
# ADR  : 0031
module Orm
  class BackupCode < ApplicationRecord
    self.table_name = "backup_codes"

    belongs_to :user, class_name: "Orm::User"
  end
end
