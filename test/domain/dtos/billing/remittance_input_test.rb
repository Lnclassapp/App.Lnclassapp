require "test_helper"

# Lot F (recette réelle) : une date de réception dans le futur et un montant démesuré ont chacun leur message.
module Dtos
  module Billing
    class RemittanceInputTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 7, 12, 0)

      def errors(**overrides)
        travel_to(NOW) do
          RemittanceInput.new({ relay_point_public_id: "pt-awa", amount_xof: "10000" }.merge(overrides)).tap(&:validate).errors
        end
      end

      test "une saisie simple est valide" do
        assert_empty errors
      end

      test "une date de réception de plus d'un jour dans le futur est refusée" do
        assert errors(received_at: "2099-01-01T10:00").of_kind?(:received_at, :in_the_future)
        assert errors(received_at: "2026-11-09T10:00").of_kind?(:received_at, :in_the_future)
      end

      test "une date passée, ou jusqu'à un jour d'avance (décalage d'horloge), est acceptée" do
        assert_empty errors(received_at: "2026-11-01T10:00")
        assert_empty errors(received_at: "2026-11-08T11:00")
      end

      test "un montant trop grand a son message, distinct de « sans virgule »" do
        too_big = errors(amount_xof: "1" * 20)

        assert too_big.of_kind?(:amount_xof, :too_large)
        assert_not too_big.of_kind?(:amount_xof, :not_an_integer)
        assert errors(amount_xof: "12,5").of_kind?(:amount_xof, :not_an_integer)
        assert errors(amount_xof: "abc").of_kind?(:amount_xof, :not_an_integer)
      end
    end
  end
end
