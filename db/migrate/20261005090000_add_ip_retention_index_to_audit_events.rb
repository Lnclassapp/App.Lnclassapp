# ADR-0080: the nightly erasure of audit IPs older than 12 months reads only the events that still carry one.
class AddIpRetentionIndexToAuditEvents < ActiveRecord::Migration[8.1]
  def change
    add_index :audit_events, :created_at, where: "ip_address IS NOT NULL", name: "index_audit_events_with_ip_on_created_at"
  end
end
