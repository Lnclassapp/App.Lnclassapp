require "test_helper"

module Entities
  module Identity
    class AuditActionTest < ActiveSupport::TestCase
      test "la liste est fermée" do
        assert_includes AuditAction::ALL, "login.locked"
        assert_includes AuditAction::ALL, "import.run"
        assert AuditAction.valid?("pin.reset")
        assert_not AuditAction.valid?("pin.changed.twice")
      end

      test "le barème des classes trace chaque nombre changé (ADR-0058)" do
        assert AuditAction.valid?("classroom_plan.changed")
      end

      test "le profil trace le changement de nom, de numéro et de PIN (ADR-0055)" do
        %w[profile.name_changed contact.changed pin.changed].each { assert AuditAction.valid?(it), it }
      end
    end
  end
end
