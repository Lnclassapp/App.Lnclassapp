require "test_helper"

module Entities
  module Assessment
    # ADR-0115 §4, PRD « La pause » : 3 copies vérifiées d'affilée (moins de 30 minutes de l'une à la suivante), puis
    # 30 minutes sans « Recommencer » après la fin de la 3e.
    class RestartPauseTest < ActiveSupport::TestCase
      def at(clock) = Time.utc(2026, 10, 28, *clock.split(":").map(&:to_i))

      def resume_at(ends, now) = RestartPause.resume_at(completions: ends.map { at(it) }, now: at(now))

      # CA-29
      test "3 copies à 10 h 00, 10 h 10 et 10 h 20 : pause jusqu'à 10 h 50, à 10 h 49" do
        assert_equal at("10:50"), resume_at(%w[10:00 10:10 10:20], "10:49")
        assert_equal at("10:50"), resume_at(%w[10:00 10:10 10:20], "10:20")
      end

      # CA-30
      test "à 10 h 50 la pause est finie" do
        assert_nil resume_at(%w[10:00 10:10 10:20], "10:50")
        assert_nil resume_at(%w[10:00 10:10 10:20], "12:00")
      end

      # CA-31
      test "3 copies à 10 h 00, 10 h 40 et 10 h 50 ne sont pas d'affilée : pas de pause" do
        assert_nil resume_at(%w[10:00 10:40 10:50], "10:55")
      end

      test "30 minutes pile entre deux fins ne sont plus « moins de 30 minutes »" do
        assert_nil resume_at(%w[10:00 10:30 10:40], "10:41")
        assert_equal at("11:10"), resume_at(%w[10:01 10:30 10:40], "10:41")
        assert_equal at("11:09"), resume_at(%w[10:01 10:30 10:39], "10:41")
      end

      test "moins de 3 copies : jamais de pause" do
        assert_nil resume_at([], "10:00")
        assert_nil resume_at(%w[10:00], "10:01")
        assert_nil resume_at(%w[10:00 10:10], "10:11")
      end

      test "seules les 3 dernières copies comptent, dans n'importe quel ordre de lecture" do
        assert_equal at("11:40"), resume_at(%w[11:10 08:00 11:00 11:09 08:30], "11:15")
        assert_nil resume_at(%w[08:00 08:10 08:20 09:30 09:40 10:20], "10:25")
      end

      test "les constantes de la règle" do
        assert_equal 3, RestartPause::STREAK
        assert_equal 1_800, RestartPause::WINDOW
      end
    end
  end
end
