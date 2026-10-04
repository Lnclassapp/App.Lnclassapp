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

      test "les annonces tracent leur publication et leur retrait (ADR-0045, ADR-0078)" do
        %w[message.published message.withdrawn].each { assert AuditAction.valid?(it), it }
        assert_not AuditAction.valid?("message.archived")
      end

      test "la direction trace le retrait et la réintégration d'un enseignant (ADR-0071)" do
        %w[teacher.detached teacher.reinstated].each { assert AuditAction.valid?(it), it }
      end

      test "le blog trace la création, la modification, la publication et l'archivage d'un article (ADR-0074, BL-07)" do
        %w[article.created article.updated article.published article.archived].each { assert AuditAction.valid?(it), it }
      end
    end
  end
end
