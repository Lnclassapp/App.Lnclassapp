require "test_helper"

# ADR-0146 §3.2 et §4.3 : toutes les 15 minutes, sur les adaptateurs réels ; l'interrupteur
# PUSH_DELIVERY_ENABLED est faux par défaut ; PUSH_MIN_INTERVAL_HOURS vaut 4 par défaut.
class Communication::DeliverPushNotificationsJobTest < ActiveJob::TestCase
  WEDNESDAY_NOON = Time.utc(2026, 11, 18, 12, 30)

  setup do
    @student = create_student
    create_push_subscription(user: @student)
    create_exercise_session(student: @student, status: "completed").update_columns(started_at: WEDNESDAY_NOON - 3.days - 10.minutes, completed_at: WEDNESDAY_NOON - 3.days)
  end

  def run_job(env = {})
    sent = []
    result = nil
    with_env({ "PUSH_DELIVERY_ENABLED" => nil, "PUSH_MIN_INTERVAL_HOURS" => nil }.merge(env)) do
      stub_any_instance(Gateways::Communication::WebPushGateway, :deliver, ->(subscription:, message:) { sent << message.body; :delivered }) do
        travel_to(WEDNESDAY_NOON) { result = Communication::DeliverPushNotificationsJob.perform_now }
      end
    end
    [ result, sent ]
  end

  def with_env(values)
    previous = values.keys.index_with { ENV[it] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  test "interrupteur absent : aucun appel au port, l'envoi est noté disabled" do
    result, sent = run_job

    assert_empty sent
    assert_equal({ "disabled" => 1 }, result)
    assert_equal [ "disabled" ], Orm::Communication::PushDelivery.pluck(:status)
  end

  test "interrupteur ouvert : l'élève inactif depuis 3 jours reçoit « Ta classe avance » une seule fois" do
    result, sent = run_job("PUSH_DELIVERY_ENABLED" => "true")

    assert_equal({ "delivered" => 1 }, result)
    assert_equal [ I18n.t("communication.push.messages.inactive.body") ], sent
    assert_equal [ "delivered" ], Orm::Communication::PushDelivery.pluck(:status)
    assert_not_nil Orm::Communication::PushSubscription.first.last_success_at

    again, sent = run_job("PUSH_DELIVERY_ENABLED" => "true")
    assert_equal({}, again)
    assert_empty sent
  end

  test "l'intervalle minimal vient de PUSH_MIN_INTERVAL_HOURS (4 h par défaut, valeur invalide = 4 h)" do
    create_push_delivery(user: @student, object_key: "ancien", sent_at: WEDNESDAY_NOON - 5.hours)
    assert_equal({ "delivered" => 1 }, run_job("PUSH_DELIVERY_ENABLED" => "1").first)
    Orm::Communication::PushDelivery.where(object_key: "ancien").update_all(sent_at: WEDNESDAY_NOON - 5.hours)
    Orm::Communication::PushDelivery.where.not(object_key: "ancien").delete_all

    assert_equal({}, run_job("PUSH_DELIVERY_ENABLED" => "1", "PUSH_MIN_INTERVAL_HOURS" => "6").first)
    assert_equal({ "delivered" => 1 }, run_job("PUSH_DELIVERY_ENABLED" => "1", "PUSH_MIN_INTERVAL_HOURS" => "abc").first)
  end

  test "le résultat est journalisé, vide compris" do
    log = capture_log do
      run_job
      travel_to(Time.utc(2026, 11, 18, 10)) { Communication::DeliverPushNotificationsJob.perform_now }
    end

    assert_includes log, "[Communication::DeliverPushNotificationsJob] push notifications by status: {\"disabled\" => 1}"
    assert_includes log, "[Communication::DeliverPushNotificationsJob] push notifications by status: {}"
  end

  test "un seul passage à la fois : la concurrence est limitée à 1 sous une clé fixe" do
    assert_equal 1, Communication::DeliverPushNotificationsJob.concurrency_limit
    assert_includes Communication::DeliverPushNotificationsJob.new.concurrency_key, "Communication::DeliverPushNotificationsJob"
  end

  test "des clés VAPID absentes sont signalées une fois par passage" do
    log = capture_log do
      with_env("PUSH_DELIVERY_ENABLED" => "true", "VAPID_PUBLIC_KEY" => nil, "VAPID_PRIVATE_KEY" => nil, "VAPID_SUBJECT" => nil) do
        travel_to(WEDNESDAY_NOON) { Communication::DeliverPushNotificationsJob.perform_now }
      end
    end

    assert_includes log, "1 student(s) not notified: VAPID keys are missing"
  end
end
