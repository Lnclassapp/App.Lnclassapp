require "test_helper"

# ADR-0146 §3.2 et §4 ; PRD §3 et §4 « Envoi : conditions » : un passage lit les candidats,
# applique fenêtre, coupure, doublon, priorité et intervalle, puis envoie une ligne par navigateur abonné.
module UseCases
  module Communication
    class DeliverPushNotificationsTest < ActiveSupport::TestCase
      Candidate = Entities::Communication::PushCandidate
      Subscription = Entities::Communication::PushSubscription

      class Candidates
        attr_reader :reads

        # reread : ce que rend la relecture d'un seul élève (par défaut, la même liste).
        def initialize(list, reread: nil) = (@list, @reread, @reads = list, reread, [])

        def for(now:, user_ids: nil)
          @reads << user_ids
          list = user_ids && @reread ? @reread : @list
          user_ids ? list.select { user_ids.include?(it.user_id) } : list
        end
      end

      class Subscriptions
        attr_reader :deleted, :successes, :failures, :resets

        def initialize(rows, failure_counts: {}, record_success_raises: false)
          @rows = rows
          @failure_counts = failure_counts
          @record_success_raises = record_success_raises
          @resets = []
          @deleted = []
          @successes = []
          @failures = []
        end

        def for_user(user_id:) = @rows.select { it.user_id == user_id }
        def delete(id:) = @deleted << id
        def record_success(id:, at:)
          raise "base indisponible" if @record_success_raises

          @successes << id
        end

        def reset_failures(id:) = @resets << id

        def record_failure(id:)
          @failures << id
          @failure_counts.fetch(id, 1)
        end
      end

      class Preferences
        def initialize(off = []) = @off = off
        def turned_off?(user_id:) = @off.include?(user_id)
      end

      class Deliveries
        attr_reader :rows, :last

        def initialize(sent: [], last: nil, recorded: true, raises_for: [])
          @sent = sent
          @recorded = recorded
          @raises_for = raises_for
          @last = last
          @rows = []
        end

        def sent?(user_id:, motive:, object_key:)
          raise "base indisponible" if @raises_for.include?(user_id)

          @sent.include?([ user_id, motive, object_key ])
        end
        def last_sent_at(user_id:) = @last
        def record(user_id:, motive:, object_key:, status:, at:)
          @rows << [ user_id, motive, object_key, status ]
          @recorded
        end
      end

      class Gateway
        attr_reader :calls

        def initialize(*answers) = (@answers = answers; @calls = [])

        def deliver(subscription:, message:)
          @calls << [ subscription.id, message ]
          @answers.size > 1 ? @answers.shift : @answers.first
        end
      end

      WEDNESDAY_NOON = Time.utc(2026, 11, 18, 12, 30)

      def candidate(user_id: 1, motive: "inactive", key: "k", valid_until: nil)
        Candidate.new(user_id:, motive:, object_key: key, url: "/", variables: {}, valid_until:)
      end

      def sub(id, user_id: 1) = Subscription.new(id:, user_id:, endpoint: "https://push.test/#{id}", p256dh: "p", auth: "a")

      def run_pass(candidates: [ candidate ], subs: [ sub(10) ], off: [], deliveries: Deliveries.new, gateway: Gateway.new(:delivered),
                   now: WEDNESDAY_NOON, enabled: true, failure_counts: {}, reread: nil, record_success_raises: false)
        subscriptions = Subscriptions.new(subs, failure_counts:, record_success_raises:)
        @candidates = Candidates.new(candidates, reread:)
        result = DeliverPushNotifications.new(candidates: @candidates, subscriptions:, preferences: Preferences.new(off),
                                              deliveries:, gateway:, clock: Struct.new(:now).new(now), delivery_enabled: enabled,
                                              min_interval: 4.hours).call
        [ result, subscriptions, deliveries, gateway ]
      end

      test "un élève abonné reçoit son motif : une ligne envoyée, noté delivered, succès de l'abonnement enregistré" do
        result, subscriptions, deliveries, gateway = run_pass

        assert result.success?
        assert_equal({ "delivered" => 1 }, result.value)
        assert_equal [ [ 10 ] ], gateway.calls.map { it.first(1) }
        assert_equal Entities::Communication::PushMessage.for(candidate), gateway.calls.first.last
        assert_equal [ [ 1, "inactive", "k", "delivered" ] ], deliveries.rows
        assert_equal [ 10 ], subscriptions.successes
      end

      test "hors fenêtre (22 h un mardi, 10 h un mercredi), rien ne part et rien n'est noté" do
        [ Time.utc(2026, 11, 17, 22), Time.utc(2026, 11, 18, 10) ].each do |now|
          result, _, deliveries, gateway = run_pass(now:)

          assert_equal({}, result.value)
          assert_empty gateway.calls
          assert_empty deliveries.rows
        end
      end

      test "un élève qui a coupé ne reçoit aucun appel au port" do
        _, _, deliveries, gateway = run_pass(off: [ 1 ])

        assert_empty gateway.calls
        assert_empty deliveries.rows
      end

      test "interrupteur PUSH_DELIVERY_ENABLED faux : aucun appel au port, envoi noté disabled" do
        result, _, deliveries, gateway = run_pass(enabled: false)

        assert_empty gateway.calls
        assert_equal [ [ 1, "inactive", "k", "disabled" ] ], deliveries.rows
        assert_equal({ "disabled" => 1 }, result.value)
      end

      test "un motif expiré est écarté, un motif encore valide part" do
        _, _, deliveries, = run_pass(candidates: [ candidate(key: "old", valid_until: WEDNESDAY_NOON - 1.minute),
                                                   candidate(key: "ok", valid_until: WEDNESDAY_NOON + 1.hour) ])

        assert_equal [ "ok" ], deliveries.rows.map { it[2] }
      end

      test "un motif déjà envoyé n'est pas renvoyé, et laisse passer le suivant" do
        deliveries = Deliveries.new(sent: [ [ 1, "quiz_prep", "a" ] ])
        _, _, deliveries, = run_pass(candidates: [ candidate(motive: "quiz_prep", key: "a"), candidate(key: "b") ], deliveries:)

        assert_equal [ [ 1, "inactive", "b", "delivered" ] ], deliveries.rows
      end

      test "un seul motif par élève et par passage : le plus prioritaire" do
        _, _, deliveries, gateway = run_pass(candidates: [ candidate(motive: "inactive", key: "i"), candidate(motive: "quiz_prep", key: "q"),
                                                           candidate(motive: "result", key: "r") ])

        assert_equal 1, gateway.calls.size
        assert_equal [ [ 1, "quiz_prep", "q", "delivered" ] ], deliveries.rows
      end

      test "chaque élève reçoit son propre motif" do
        _, _, deliveries, = run_pass(candidates: [ candidate(user_id: 1), candidate(user_id: 2) ], subs: [ sub(10), sub(11, user_id: 2) ])

        assert_equal [ 1, 2 ], deliveries.rows.map(&:first)
      end

      test "pas de nouvel envoi moins de 4 h après le dernier envoi réussi, un envoi plus ancien laisse passer" do
        _, _, recent, gateway = run_pass(deliveries: Deliveries.new(last: WEDNESDAY_NOON - 3.hours - 59.minutes))
        assert_empty gateway.calls
        assert_empty recent.rows

        _, _, old, = run_pass(deliveries: Deliveries.new(last: WEDNESDAY_NOON - 4.hours))
        assert_equal 1, old.rows.size
      end

      test "aucun abonnement : rien n'est envoyé ni noté" do
        result, _, deliveries, gateway = run_pass(subs: [])

        assert_empty gateway.calls
        assert_empty deliveries.rows
        assert_equal({}, result.value)
      end

      test "abonnement refusé (gone) : supprimé, noté gone" do
        _, subscriptions, deliveries, = run_pass(gateway: Gateway.new(:gone))

        assert_equal [ 10 ], subscriptions.deleted
        assert_equal "gone", deliveries.rows.first.last
      end

      test "échec passager : échec compté, noté retry" do
        result, subscriptions, deliveries, = run_pass(gateway: Gateway.new(:retry))

        assert_equal [ 10 ], subscriptions.failures
        assert_equal "retry", deliveries.rows.first.last
        assert_equal({ "retry" => 1 }, result.value)
      end

      test "au troisième échec, le statut passe à failed" do
        _, _, deliveries, = run_pass(gateway: Gateway.new(:retry), failure_counts: { 10 => 3 })

        assert_equal "failed", deliveries.rows.first.last
      end

      test "non configuré : noté not_configured, aucun échec compté, aucune erreur" do
        result, subscriptions, deliveries, = run_pass(gateway: Gateway.new(:not_configured))

        assert result.success?
        assert_empty subscriptions.failures
        assert_equal "not_configured", deliveries.rows.first.last
      end

      test "plusieurs navigateurs : une ligne chacun, delivered si au moins un a reçu" do
        _, subscriptions, deliveries, gateway = run_pass(subs: [ sub(10), sub(11) ], gateway: Gateway.new(:gone, :delivered))

        assert_equal [ 10, 11 ], gateway.calls.map(&:first)
        assert_equal [ 10 ], subscriptions.deleted
        assert_equal [ 11 ], subscriptions.successes
        assert_equal [ "delivered" ], deliveries.rows.map(&:last)
      end

      test "statut agrégé : retry avant failed avant not_configured avant gone" do
        { %i[retry gone] => "retry", %i[not_configured gone] => "not_configured", %i[gone gone] => "gone" }.each do |answers, status|
          _, _, deliveries, = run_pass(subs: [ sub(10), sub(11) ], gateway: Gateway.new(*answers))

          assert_equal [ status ], deliveries.rows.map(&:last), answers.inspect
        end

        _, _, deliveries, = run_pass(subs: [ sub(10), sub(11) ], gateway: Gateway.new(:retry, :gone), failure_counts: { 10 => 3 })
        assert_equal [ "failed" ], deliveries.rows.map(&:last)
      end

      test "au troisième échec, le compteur de l'abonnement repart de zéro ; avant, il n'est pas remis à zéro" do
        _, subscriptions, = run_pass(gateway: Gateway.new(:retry), failure_counts: { 10 => 3 })
        assert_equal [ 10 ], subscriptions.resets

        _, subscriptions, = run_pass(gateway: Gateway.new(:retry), failure_counts: { 10 => 2 })
        assert_empty subscriptions.resets
      end

      test "deux échecs déjà comptés : le troisième est failed, le deuxième encore retry" do
        _, _, deliveries, = run_pass(gateway: Gateway.new(:retry), failure_counts: { 10 => 2 })

        assert_equal "retry", deliveries.rows.first.last
      end

      test "retry sur un navigateur et delivered sur l'autre : delivered" do
        _, _, deliveries, = run_pass(subs: [ sub(10), sub(11) ], gateway: Gateway.new(:retry, :delivered))

        assert_equal [ "delivered" ], deliveries.rows.map(&:last)
      end

      test "failed l'emporte sur not_configured" do
        _, _, deliveries, = run_pass(subs: [ sub(10), sub(11) ], gateway: Gateway.new(:retry, :not_configured), failure_counts: { 10 => 3 })

        assert_equal [ "failed" ], deliveries.rows.map(&:last)
      end

      test "une réponse inconnue de la passerelle est un bug : le passage signale l'élève et n'écrit rien" do
        reported = capture_reports { run_pass(gateway: Gateway.new(:boom)) }

        assert_equal [ ArgumentError ], reported.map { it[:error].class }
        assert_equal 1, reported.first[:context][:user_id]
      end

      test "12 h 05 envoyé, 13 h bloqué par l'intervalle de 4 h, 17 h part" do
        deliveries = Deliveries.new
        run_pass(deliveries:, now: Time.utc(2026, 11, 18, 12, 5))
        assert_equal 1, deliveries.rows.size

        blocked = Deliveries.new(last: Time.utc(2026, 11, 18, 12, 5))
        run_pass(deliveries: blocked, now: Time.utc(2026, 11, 18, 13))
        assert_empty blocked.rows

        late = Deliveries.new(last: Time.utc(2026, 11, 18, 12, 5))
        run_pass(deliveries: late, now: Time.utc(2026, 11, 18, 17))
        assert_equal 1, late.rows.size
      end

      test "assignment_due contre quiz_prep : seule l'interro part" do
        _, _, deliveries, = run_pass(candidates: [ candidate(motive: "assignment_due", key: "d"), candidate(motive: "quiz_prep", key: "q") ])

        assert_equal [ [ 1, "quiz_prep", "q", "delivered" ] ], deliveries.rows
      end

      test "PRD 3.7 : le motif relu pour ce seul élève n'est plus prêt : aucun appel au port, aucune ligne" do
        _, _, deliveries, gateway = run_pass(reread: [])

        assert_empty gateway.calls
        assert_empty deliveries.rows
        assert_equal [ nil, [ 1 ] ], @candidates.reads
      end

      test "PRD 3.7 : le motif relu et encore prêt part ; un motif relu expiré ne part pas" do
        _, _, deliveries, = run_pass(reread: [ candidate ])
        assert_equal 1, deliveries.rows.size

        _, _, expired, gateway = run_pass(reread: [ candidate(valid_until: WEDNESDAY_NOON - 1.minute) ])
        assert_empty gateway.calls
        assert_empty expired.rows
      end

      test "le dépôt échoue pour un élève : l'erreur est signalée et les élèves suivants sont servis" do
        deliveries = Deliveries.new(raises_for: [ 1 ])
        reported = capture_reports do
          _, _, @out, = run_pass(candidates: [ candidate(user_id: 1), candidate(user_id: 2) ], subs: [ sub(10), sub(11, user_id: 2) ], deliveries:)
        end

        assert_equal [ 2 ], deliveries.rows.map(&:first)
        assert_equal [ { user_id: 1, motive: "inactive" } ], reported.map { it[:context] }
      end

      test "l'écriture après le départ échoue : l'envoi est quand même noté (ensure), l'erreur est signalée" do
        reported = capture_reports do
          _, _, @deliveries, = run_pass(record_success_raises: true)
        end

        assert_equal [ [ 1, "inactive", "k", "delivered" ] ], @deliveries.rows
        assert_equal 1, reported.size
      end

      test "un envoi parti dont l'écriture renvoie faux (déjà noté) est journalisé" do
        log = capture_log { run_pass(deliveries: Deliveries.new(recorded: false)) }

        assert_includes log, "delivery already recorded after a sent push: user 1, motive inactive"
      end

      test "un statut non delivered dont l'écriture renvoie faux n'est pas journalisé" do
        assert_not_includes capture_log { run_pass(gateway: Gateway.new(:gone), deliveries: Deliveries.new(recorded: false)) }, "already recorded"
      end

      def capture_reports
        reports = []
        subscriber = Class.new do
          define_method(:report) { |error, handled:, severity:, context:, source: nil| reports << { error:, context: } }
        end.new
        Rails.error.subscribe(subscriber)
        yield
        reports
      ensure
        Rails.error.unsubscribe(subscriber)
      end
    end
  end
end
