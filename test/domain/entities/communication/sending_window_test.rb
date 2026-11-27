require "test_helper"

# PRD §3.1, ADR-0147 §4.3 (porteur, 2026-11-27) : lundi-samedi 12 h 20-14 h et 18 h-20 h 20, dimanche 9 h-20 h,
# à l'heure d'Abidjan (UTC+0).
module Entities
  module Communication
    class SendingWindowTest < ActiveSupport::TestCase
      MONDAY = Time.utc(2026, 11, 16)
      SATURDAY = Time.utc(2026, 11, 21)
      SUNDAY = Time.utc(2026, 11, 22)

      def at(day, hour, minute = 0) = day + hour.hours + minute.minutes

      test "un jour de semaine, ouvert de 12 h 20 à 14 h et de 18 h à 20 h 20 seulement" do
        { [ 8, 0 ] => false, [ 12, 0 ] => false, [ 12, 19 ] => false, [ 12, 20 ] => true, [ 13, 59 ] => true, [ 14, 0 ] => false,
          [ 17, 0 ] => false, [ 17, 59 ] => false, [ 18, 0 ] => true, [ 20, 0 ] => true, [ 20, 19 ] => true, [ 20, 20 ] => false,
          [ 22, 0 ] => false }.each do |(hour, minute), open|
          assert_equal open, SendingWindow.open?(at(MONDAY, hour, minute)), "lundi #{hour} h #{minute}"
        end
      end

      test "le samedi suit les fenêtres de la semaine" do
        assert SendingWindow.open?(at(SATURDAY, 12, 20))
        assert SendingWindow.open?(at(SATURDAY, 20, 19))
        assert_not SendingWindow.open?(at(SATURDAY, 9, 0))
      end

      test "le dimanche, ouvert de 9 h à 20 h" do
        { [ 8, 59 ] => false, [ 9, 0 ] => true, [ 15, 0 ] => true, [ 19, 59 ] => true, [ 20, 0 ] => false, [ 20, 10 ] => false }.each do |(hour, minute), open|
          assert_equal open, SendingWindow.open?(at(SUNDAY, hour, minute)), "dimanche #{hour} h #{minute}"
        end
      end

      test "un instant d'un autre fuseau est lu à l'heure d'Abidjan" do
        assert SendingWindow.open?(Time.new(2026, 11, 16, 13, 20, 0, "+01:00")) # 12 h 20 à Abidjan
        assert_not SendingWindow.open?(Time.new(2026, 11, 16, 13, 0, 0, "+01:00")) # 12 h
        assert SendingWindow.open?(Time.new(2026, 11, 16, 22, 10, 0, "+02:00")) # 20 h 10
      end

      test "ouvert : l'instant lui-même" do
        assert_equal at(MONDAY, 12, 20), SendingWindow.next_open_at(at(MONDAY, 12, 20))
      end

      test "la prochaine ouverture, le même jour" do
        assert_equal at(MONDAY, 12, 20), SendingWindow.next_open_at(at(MONDAY, 10))
        assert_equal at(MONDAY, 12, 20), SendingWindow.next_open_at(at(MONDAY, 12, 5))
        assert_equal at(MONDAY, 18), SendingWindow.next_open_at(at(MONDAY, 14))
      end

      test "un mardi après 20 h 20, rien avant 12 h 20 le mercredi" do
        assert_equal Time.utc(2026, 11, 18, 12, 20), SendingWindow.next_open_at(Time.utc(2026, 11, 17, 20, 20))
      end

      test "le samedi soir, la prochaine ouverture est le dimanche à 9 h" do
        assert_equal at(SUNDAY, 9), SendingWindow.next_open_at(at(SATURDAY, 21))
      end

      test "le dimanche soir, la prochaine ouverture est le lundi à 12 h 20" do
        assert_equal Time.utc(2026, 11, 23, 12, 20), SendingWindow.next_open_at(at(SUNDAY, 20))
      end
    end
  end
end
