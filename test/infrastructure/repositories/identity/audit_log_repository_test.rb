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

      # RI-01, RI-02 (ADR-0080) : l'IP des événements échus est effacée par lots ; le reste de l'événement demeure.
      test "erase_ips_before empties the IP of the events created before the date, in batches, and nothing else" do
        at = Time.zone.parse("2026-10-05 04:30")
        actor = create_team_member(second_factor: false)
        old = Orm::AuditEvent.create!(action: "invitation.sent", actor_id: actor.id, subject_type: "User", subject_id: 2,
                                      metadata: { "kind" => "team" }, ip_address: "10.0.0.1", created_at: at - 1.second)
        recent = Orm::AuditEvent.create!(action: "invitation.sent", ip_address: "10.0.0.2", created_at: at)
        4.times { Orm::AuditEvent.create!(action: "pin.reset", ip_address: "10.0.0.3", created_at: at - 1.day) }
        Orm::AuditEvent.create!(action: "pin.reset", ip_address: nil, created_at: at - 1.day)

        assert_equal 5, @repository.erase_ips_before(at:, batch_size: 2)
        assert_nil old.reload.ip_address
        assert_equal [ "invitation.sent", actor.id, "User", 2, { "kind" => "team" }, at - 1.second ],
                     [ old.action, old.actor_id, old.subject_type, old.subject_id, old.metadata, old.created_at ]
        assert_equal "10.0.0.2", recent.reload.ip_address
        assert_equal 0, @repository.erase_ips_before(at:, batch_size: 2)
      end
    end
  end
end
