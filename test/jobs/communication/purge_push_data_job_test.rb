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

    result = Communication::PurgePushDataJob.perform_now

    assert_equal({ subscriptions: 2, deliveries: 1 }, result)
    assert_equal [ fresh.id, new_one.id ].sort, Orm::Communication::PushSubscription.ids.sort
    assert_empty Orm::Communication::PushSubscription.where(id: [ stale.id, never.id ])
    assert_equal [ recent_delivery.id ], Orm::Communication::PushDelivery.ids
    assert_not Orm::Communication::PushDelivery.exists?(old_delivery.id)
  end

  test "les nombres supprimés sont journalisés, zéro compris" do
    create_push_delivery(user: create_student, sent_at: 91.days.ago)

    logs = [ capture_log { Communication::PurgePushDataJob.perform_now }, capture_log { Communication::PurgePushDataJob.perform_now } ]

    assert_includes logs.first, "[Communication::PurgePushDataJob] 0 stale push subscription(s) and 1 old push delivery(ies) deleted"
    assert_includes logs.last, "[Communication::PurgePushDataJob] 0 stale push subscription(s) and 0 old push delivery(ies) deleted"
  end
end
