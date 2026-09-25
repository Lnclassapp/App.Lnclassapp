require "test_helper"

module Entities
  module Identity
    class AuditActionTest < ActiveSupport::TestCase
      test "la liste est fermée" do
        assert_includes AuditAction::ALL, "login.locked"
        assert_includes AuditAction::ALL, "import.run"
        assert AuditAction.valid?("pin.reset")
        assert_not AuditAction.valid?("pin.changed")
      end
    end
  end
end
