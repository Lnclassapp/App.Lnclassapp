# 🔌 INFRA · Orm::TotpCredential
# Rôle : table totp_credentials, secret TOTP chiffré par Active Record Encryption
# ADR  : 0031
module Orm
  class TotpCredential < ApplicationRecord
    self.table_name = "totp_credentials"

    encrypts :secret

    belongs_to :user, class_name: "Orm::User", inverse_of: :totp_credential
  end
end
