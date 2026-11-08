require "test_helper"

module Queries
  module Billing
    class CashboxQueryTest < ActiveSupport::TestCase
      FRIDAY = Time.utc(2026, 11, 13, 12)

      setup do
        @query = CashboxQuery.new
        @awa = Orm::Billing::RelayPoint.find_by!(name: "Boutique Awa")
        @team = create_team_member
      end

      def awa_line(at: FRIDAY) = @query.call(at:).relays.find { it.id == @awa.id }

      test "la Boutique Awa doit 10 000 F et a 15 cartes en circulation" do
        line = awa_line

        assert_equal [ 20, 3, 2, 15, 20_000, 10_000 ],
                     [ line.issued_count, line.activated_count, line.cancelled_count, line.in_circulation, line.remitted_xof, line.due_xof ]
      end

      test "un versement négatif ramène le total versé et le dû" do
        Repositories::Billing::RemittanceRepository.new.record(relay_point_id: @awa.id, amount_xof: 10_000, received_at: FRIDAY, reference: nil,
                                                               reason: nil, recorded_by_id: @team.id)
        assert_equal 30_000, awa_line.remitted_xof
        Repositories::Billing::RemittanceRepository.new.record(relay_point_id: @awa.id, amount_xof: -10_000, received_at: FRIDAY, reference: nil,
                                                               reason: "erreur", recorded_by_id: @team.id)

        assert_equal [ 20_000, 10_000 ], [ awa_line.remitted_xof, awa_line.due_xof ]
      end

      test "le vendredi 13, la semaine écoulée doit 400 F pour 2 activations du jeudi et la semaine en cours en compte 1" do
        cashbox = @query.call(at: FRIDAY)

        assert_equal Date.new(2026, 11, 6), cashbox.last_week.week.starts_on
        assert_equal [ [ "Boutique Awa", 2, 400 ] ], cashbox.last_week.lines.map { [ it.name, it.activations, it.commission_xof ] }
        assert_equal 400, cashbox.last_week.total_xof
        assert_equal 1, cashbox.current_week_activations
      end

      test "une semaine sans activation payante est vide ; les semaines précédentes sont au nombre de 8" do
        cashbox = @query.call(at: Time.utc(2026, 11, 27, 9))

        assert_empty cashbox.last_week.lines
        assert_equal 0, cashbox.last_week.total_xof
        assert_equal 8, cashbox.past_weeks.size
        assert_equal Date.new(2026, 11, 13), cashbox.past_weeks.first.week.starts_on
        assert_equal 1, cashbox.past_weeks.find { it.week.starts_on == Date.new(2026, 11, 13) }.lines.sum(&:activations)
      end

      test "les cartes offertes ne comptent ni dans le dû ni dans les commissions" do
        free = Repositories::Billing::CardRepository.new.create_batch(relay_point_id: @awa.id, quantity: 1, unit_price_xof: 0,
                                                                      valid_until: Date.new(2027, 7, 31), created_by_id: @team.id, at: FRIDAY)
        Repositories::Billing::CardRepository.new.activate(card_id: free.cards.first.id, student_id: create_student.id, school_id: nil, at: FRIDAY)

        line = awa_line
        assert_equal [ 21, 4, 10_000 ], [ line.issued_count, line.activated_count, line.due_xof ]
        assert_equal 1, @query.call(at: FRIDAY).current_week_activations
      end

      test "l'école cumule 1 000 F par carte payante activée par ses élèves, pas pour une carte offerte" do
        school = create_school(name: "Collège Saint Michel")
        cards = Repositories::Billing::CardRepository.new
        paid = cards.create_batch(relay_point_id: @awa.id, quantity: 3, unit_price_xof: 10_000, valid_until: Date.new(2027, 7, 31),
                                  created_by_id: @team.id, at: FRIDAY)
        free = cards.create_batch(relay_point_id: @awa.id, quantity: 1, unit_price_xof: 0, valid_until: Date.new(2027, 7, 31),
                                  created_by_id: @team.id, at: FRIDAY)
        (paid.cards + free.cards).each { cards.activate(card_id: it.id, student_id: create_student.id, school_id: school.id, at: FRIDAY) }

        schools = @query.call(at: FRIDAY).schools

        assert_equal [ [ "Collège Saint Michel", 3, 3_000 ] ], schools.map { [ it.name, it.subscriptions, it.commission_xof ] }
      end

      test "pas de requête par point relais" do
        3.times { Orm::Billing::RelayPoint.create!(name: "Relais #{it}", location: "Ici", phone: "07 00 00 00 00") }
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }

        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { @query.call(at: FRIDAY) }

        assert_operator count, :<=, 8
      end

      test "liste les points relais pour le choix d'un versement" do
        assert_includes @query.relay_points.map(&:name), "Boutique Awa"
      end
    end
  end
end
