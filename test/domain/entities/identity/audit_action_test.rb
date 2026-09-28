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

      test "le profil trace l'ajout, le changement et le retrait de la photo (ADR-0060)" do
        %w[profile.photo_changed profile.photo_removed].each { assert AuditAction.valid?(it), it }
      end

      test "la direction trace ses retraits, réintégrations et changements de classe ; l'élève son matricule (ADR-0065, 0066)" do
        %w[staff.detached teacher.detached teacher.reinstated student.placed student_number.changed].each do |action|
          assert AuditAction.valid?(action), action
        end
      end
    end
  end
end
