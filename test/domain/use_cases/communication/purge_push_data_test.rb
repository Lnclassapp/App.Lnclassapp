require "test_helper"

# ADR-0146 §4.1 : abonnements sans envoi réussi depuis 60 jours, envois de plus de 90 jours.
module UseCases
  module Communication
    class PurgePushDataTest < ActiveSupport::TestCase
      class Subscriptions
        attr_reader :before

        def delete_stale(before:) = (@before = before; 2)
      end

      class Deliveries
        attr_reader :before

        def purge_before(before:) = (@before = before; 5)
      end

      test "purge les abonnements de plus de 60 jours et les envois de plus de 90 jours, et compte" do
        now = Time.utc(2026, 11, 18, 5)
        subscriptions = Subscriptions.new
        deliveries = Deliveries.new

        result = PurgePushData.new(subscriptions:, deliveries:, clock: Struct.new(:now).new(now)).call

        assert result.success?
        assert_equal({ subscriptions: 2, deliveries: 5 }, result.value)
        assert_equal now - 60.days, subscriptions.before
        assert_equal now - 90.days, deliveries.before
      end
    end
  end
end
