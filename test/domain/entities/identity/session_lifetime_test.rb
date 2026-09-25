require "test_helper"

module Entities
  module Identity
    class SessionLifetimeTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)

      test "un élève expire après 30 jours d'inactivité, jamais par ancienneté" do
        assert_not SessionLifetime.expired?(role: :student, created_at: NOW - 200.days, last_seen_at: NOW - 29.days, now: NOW)
        assert SessionLifetime.expired?(role: :student, created_at: NOW - 30.days, last_seen_at: NOW - 30.days, now: NOW)
      end

      test "team et direction expirent après 12 h d'ancienneté" do
        assert_not SessionLifetime.expired?(role: "team", created_at: NOW - 11.hours, last_seen_at: NOW, now: NOW)
        assert SessionLifetime.expired?(role: :team, created_at: NOW - 12.hours, last_seen_at: NOW, now: NOW)
        assert SessionLifetime.expired?(role: :school_admin, created_at: NOW - 13.hours, last_seen_at: NOW, now: NOW)
      end

      test "la dernière visite n'est réécrite que toutes les 5 minutes" do
        assert_not SessionLifetime.touch_due?(last_seen_at: NOW - 4.minutes, now: NOW)
        assert SessionLifetime.touch_due?(last_seen_at: NOW - 5.minutes, now: NOW)
      end
    end
  end
end
