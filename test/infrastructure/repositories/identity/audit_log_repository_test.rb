require "test_helper"

module Repositories
  module Identity
    class AuditLogRepositoryTest < ActiveSupport::TestCase
      setup { @repository = AuditLogRepository.new }

      test "record appends an event" do
        member = create_team_member
        at = Time.current.change(usec: 0)

        assert @repository.record(action: "totp.enrolled", actor_id: member.id, subject_type: "User", subject_id: member.id,
                                  metadata: { "via" => "enrollment" }, ip: "10.0.0.1", at:)

        event = Orm::AuditEvent.last
        assert_equal [ "totp.enrolled", member.id, "User", member.id, { "via" => "enrollment" }, "10.0.0.1", at ],
                     event.values_at(:action, :actor_id, :subject_type, :subject_id, :metadata, :ip_address, :created_at)
      end

      test "an anonymous event keeps empty defaults" do
        @repository.record(action: "login.locked", actor_id: nil, at: Time.current)

        assert_equal [ nil, {}, nil ], Orm::AuditEvent.last.values_at(:actor_id, :metadata, :ip_address)
      end

      test "an action outside the closed list is refused" do
        assert_raises(ArgumentError) { @repository.record(action: "login.failed", actor_id: nil, at: Time.current) }
      end
    end
  end
end
