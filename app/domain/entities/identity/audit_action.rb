# 🧠 DOMAINE · Entities::Identity::AuditAction
# Rôle : liste fermée des actions écrites dans le journal d'audit

# ADR  : 0031, 0032, 0035, 0038, 0050, 0055, 0058
module Entities
  module Identity
    module AuditAction
      ALL = %w[
        login.locked totp.enrolled totp.reset backup_code.used
        pin.recovery_code_issued pin.reset invitation.sent invitation.accepted team_role.changed
        content.published content.archived taxonomy.changed school.changed import.run classroom_plan.changed
        profile.name_changed contact.changed pin.changed
        profile.photo_changed profile.photo_removed
      ].freeze

      def self.valid?(action) = ALL.include?(action)
    end
  end
end
