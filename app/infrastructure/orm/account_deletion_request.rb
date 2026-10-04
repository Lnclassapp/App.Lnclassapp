# 🔌 INFRA · Orm::AccountDeletionRequest
# Rôle : table account_deletion_requests, demande de suppression d'un compte reçue par le support, en attente ou close
# ADR  : 0027, 0036 (amendement 2 du 2026-10-02)
module Orm
  class AccountDeletionRequest < ApplicationRecord
    self.table_name = "account_deletion_requests"

    belongs_to :user, class_name: "Orm::User"
    belongs_to :recorded_by, class_name: "Orm::User"
    belongs_to :closed_by, class_name: "Orm::User", optional: true
  end
end
