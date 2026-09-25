# 🔌 INFRA · Orm::LoginAttempt
# Rôle : table login_attempts, tentatives de PIN et de second facteur (verrouillage progressif)
# ADR  : 0050
module Orm
  class LoginAttempt < ApplicationRecord
    self.table_name = "login_attempts"

    belongs_to :user, class_name: "Orm::User", optional: true
  end
end
