# 🔌 INFRA · Orm::AuditEvent
# Rôle : table audit_events, journal d'audit en ajout seul : une ligne créée ne change plus
# ADR  : 0050
module Orm
  class AuditEvent < ApplicationRecord
    self.table_name = "audit_events"

    belongs_to :actor, class_name: "Orm::User", optional: true

    def readonly? = persisted? || super
  end
end
