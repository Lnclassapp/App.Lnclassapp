require "test_helper"

# ADR-0146 §3.2 et §4.3 : toutes les 15 minutes, sur les adaptateurs réels ; l'interrupteur
# PUSH_DELIVERY_ENABLED est faux par défaut ; ADR envois de notifications §4.3 : rien ne part sans réglage ni validation.
class Communication::DeliverPushNotificationsJobTest < ActiveJob::TestCase
  WEDNESDAY_NOON = Time.utc(2026, 11, 18, 12, 30)

  setup do
    @student = create_student
    create_push_subscription(user: @student)
    create_exercise_session(student: @student, status: "completed").update_columns(started_at: WEDNESDAY_NOON - 3.days - 10.minutes, completed_at: WEDNESDAY_NOON - 3.days)
  end

  def approve_inactive = create_push_approval(motive: "inactive", on_date: WEDNESDAY_NOON.to_date, recipients: [ [ @student.id, inactive_key ] ])

  def inactive_key = Queries::Communication::PushCandidates.new.for(now: WEDNESDAY_NOON).sole.object_key

  def run_job(env = {})
    sent = []
    result = nil
    with_env({ "PUSH_DELIVERY_ENABLED" => nil }.merge(env)) do
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

  test "sans réglage ni validation, un passage n'envoie rien et ne note rien" do
    result, sent = run_job("PUSH_DELIVERY_ENABLED" => "true")

    assert_empty sent
    assert_equal({}, result)
    assert_empty Orm::Communication::PushDelivery.all
  end

  test "interrupteur absent : aucun appel au port, l'envoi est noté disabled" do
    approve_inactive
    result, sent = run_job

    assert_empty sent
    assert_equal({ "disabled" => 1 }, result)
    assert_equal [ "disabled" ], Orm::Communication::PushDelivery.pluck(:status)
  end

  test "interrupteur ouvert : l'élève inactif depuis 3 jours, validé par l'équipe, reçoit « Ta classe avance » une seule fois" do
    approve_inactive
    result, sent = run_job("PUSH_DELIVERY_ENABLED" => "true")

    assert_equal({ "delivered" => 1 }, result)
    assert_equal [ I18n.t("communication.push.messages.inactive.body") ], sent
    assert_equal [ "delivered" ], Orm::Communication::PushDelivery.pluck(:status)
    assert_not_nil Orm::Communication::PushSubscription.first.last_success_at

    again, sent = run_job("PUSH_DELIVERY_ENABLED" => "true")
    assert_equal({}, again)
    assert_empty sent
  end

  test "un motif automatique part sans validation : la case « Devoir à rendre » ouvre le motif pour tous" do
    create_push_motive_setting(motive: "assignment_due", automatic: true)
    classroom = create_classroom
    student = create_student(classroom:)
    create_push_subscription(user: student)
    course = create_course(material: create_material(name: "Géographie"), level: classroom.level)
    3.times do
      create_assignment(classroom:, assignable: create_exercise(course:), by: create_teacher, batch_public_id: "AUTO".ljust(14, "0"),
                        due_on: WEDNESDAY_NOON.to_date + 1, assigned_at: WEDNESDAY_NOON - 1.day)
    end

    result, sent = run_job("PUSH_DELIVERY_ENABLED" => "true")

    assert_equal({ "delivered" => 1 }, result)
    assert_equal [ I18n.t("communication.push.messages.assignment_due.body", material: "Géographie") ], sent
  end

  test "dix envois déjà partis ce jour : plus rien ne part ; PUSH_MIN_INTERVAL_HOURS n'est plus lue" do
    approve_inactive
    10.times { |i| create_push_delivery(user: @student, motive: "result", object_key: "result:#{i}", sent_at: WEDNESDAY_NOON - 3.hours) }

    result, sent = run_job("PUSH_DELIVERY_ENABLED" => "true", "PUSH_MIN_INTERVAL_HOURS" => "6")

    assert_equal({}, result)
    assert_empty sent
  end

  test "un envoi parti il y a une heure ne bloque plus l'élève : l'écart de 4 h est supprimé" do
    approve_inactive
    create_push_delivery(user: @student, object_key: "ancien", sent_at: WEDNESDAY_NOON - 1.hour)

    assert_equal({ "delivered" => 1 }, run_job("PUSH_DELIVERY_ENABLED" => "1").first)
  end

  test "le résultat est journalisé, vide compris" do
    approve_inactive
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
    approve_inactive
    log = capture_log do
      with_env("PUSH_DELIVERY_ENABLED" => "true", "VAPID_PUBLIC_KEY" => nil, "VAPID_PRIVATE_KEY" => nil, "VAPID_SUBJECT" => nil) do
        travel_to(WEDNESDAY_NOON) { Communication::DeliverPushNotificationsJob.perform_now }
      end
    end

    assert_includes log, "1 student(s) not notified: VAPID keys are missing"
  end
end
