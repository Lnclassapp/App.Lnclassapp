require "test_helper"

# PRD §3.1 : lundi-samedi 12 h-14 h et 17 h-20 h, dimanche 9 h-20 h, à l'heure d'Abidjan (UTC+0).
module Entities
  module Communication
    class SendingWindowTest < ActiveSupport::TestCase
      MONDAY = Time.utc(2026, 11, 16)
      SUNDAY = Time.utc(2026, 11, 22)

      test "un jour de semaine, ouvert à midi et le soir seulement" do
        { 8 => false, 11 => false, 12 => true, 13 => true, 14 => false, 16 => false, 17 => true, 19 => true, 20 => false, 22 => false }.each do |hour, open|
          assert_equal open, SendingWindow.open?(MONDAY + hour.hours), "lundi #{hour} h"
        end
      end

      test "le dimanche, ouvert de 9 h à 20 h" do
        { 8 => false, 9 => true, 15 => true, 19 => true, 20 => false }.each do |hour, open|
          assert_equal open, SendingWindow.open?(SUNDAY + hour.hours), "dimanche #{hour} h"
        end
      end

      test "la fin de la fenêtre est exclue à la minute près" do
        assert SendingWindow.open?(MONDAY + 13.hours + 59.minutes)
        assert_not SendingWindow.open?(MONDAY + 14.hours)
      end

      test "un instant d'un autre fuseau est lu à l'heure d'Abidjan" do
        assert SendingWindow.open?(Time.new(2026, 11, 16, 13, 0, 0, "+01:00")) # 12 h à Abidjan
        assert_not SendingWindow.open?(Time.new(2026, 11, 16, 12, 0, 0, "+01:00")) # 11 h
        assert SendingWindow.open?(Time.new(2026, 11, 16, 14, 0, 0, "+02:00")) # 12 h
      end

      test "ouvert : l'instant lui-même" do
        assert_equal MONDAY + 12.hours, SendingWindow.next_open_at(MONDAY + 12.hours)
      end

      test "la prochaine ouverture, le même jour" do
        assert_equal MONDAY + 12.hours, SendingWindow.next_open_at(MONDAY + 10.hours)
        assert_equal MONDAY + 17.hours, SendingWindow.next_open_at(MONDAY + 14.hours)
      end

      test "un mardi à 22 h, rien avant midi le mercredi" do
        assert_equal Time.utc(2026, 11, 18, 12), SendingWindow.next_open_at(Time.utc(2026, 11, 17, 22))
      end

      test "le samedi soir, la prochaine ouverture est le dimanche à 9 h" do
        assert_equal SUNDAY + 9.hours, SendingWindow.next_open_at(Time.utc(2026, 11, 21, 21))
      end

      test "le dimanche soir, la prochaine ouverture est le lundi à midi" do
        assert_equal Time.utc(2026, 11, 23, 12), SendingWindow.next_open_at(SUNDAY + 21.hours)
      end
    end
  end
end
