require "test_helper"

# ADR-0146 §4.1 : abonnements sans envoi réussi depuis 60 jours, envois de plus de 90 jours.
class Communication::PurgePushDataJobTest < ActiveJob::TestCase
  test "supprime les abonnements périmés et les envois de plus de 90 jours, garde le reste" do
    student = create_student
    stale = create_push_subscription(user: student, last_success_at: 61.days.ago)
    never = create_push_subscription(user: student, created_at: 61.days.ago, updated_at: 61.days.ago)
    fresh = create_push_subscription(user: student, last_success_at: 59.days.ago)
    new_one = create_push_subscription(user: student)
    old_delivery = create_push_delivery(user: student, sent_at: 91.days.ago)
    recent_delivery = create_push_delivery(user: student, sent_at: 89.days.ago)

    old_approval = create_push_approval(on_date: 91.days.ago.to_date, approved_at: 91.days.ago, recipients: [ [ student.id, "unfinished:x" ] ])
    recent_approval = create_push_approval(on_date: 89.days.ago.to_date, approved_at: 89.days.ago, motive: "result")
    old_change = Orm::Communication::PushMotiveSettingChange.create!(motive: "assignment_due", automatic: true, changed_by: create_team_member, changed_at: 91.days.ago)
    recent_change = Orm::Communication::PushMotiveSettingChange.create!(motive: "assignment_due", automatic: false, changed_by: create_team_member, changed_at: 89.days.ago)

    result = Communication::PurgePushDataJob.perform_now

    assert_equal({ subscriptions: 2, deliveries: 1, approvals: 1, setting_changes: 1 }, result)
    assert_equal [ recent_approval.id ], Orm::Communication::PushApproval.ids
    assert_empty Orm::Communication::PushApprovalRecipient.where(push_approval_id: old_approval.id)
    assert_equal [ recent_change.id ], Orm::Communication::PushMotiveSettingChange.ids
    assert_not Orm::Communication::PushMotiveSettingChange.exists?(old_change.id)
    assert_equal [ fresh.id, new_one.id ].sort, Orm::Communication::PushSubscription.ids.sort
    assert_empty Orm::Communication::PushSubscription.where(id: [ stale.id, never.id ])
    assert_equal [ recent_delivery.id ], Orm::Communication::PushDelivery.ids
    assert_not Orm::Communication::PushDelivery.exists?(old_delivery.id)
  end

  test "les nombres supprimés sont journalisés, zéro compris" do
    create_push_delivery(user: create_student, sent_at: 91.days.ago)

    logs = [ capture_log { Communication::PurgePushDataJob.perform_now }, capture_log { Communication::PurgePushDataJob.perform_now } ]

    assert_includes logs.first, "[Communication::PurgePushDataJob] 0 stale push subscription(s) and 1 old push delivery(ies), 0 old push approval(s) and 0 old setting change(s) deleted"
    assert_includes logs.last, "[Communication::PurgePushDataJob] 0 stale push subscription(s) and 0 old push delivery(ies), 0 old push approval(s) and 0 old setting change(s) deleted"
  end
end
