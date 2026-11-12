require "test_helper"

# hors-connexion, Lot 0 (ADR §4.5, menace R4) : l'heure d'origine d'une copie hors ligne est ramenée dans
# [émission du paquet, réception], jamais plus de 30 jours avant la réception.
module Entities
  module Assessment
    class OfflineCopyWindowTest < ActiveSupport::TestCase
      RECEIVED = Time.utc(2026, 11, 12, 12)
      ISSUED = RECEIVED - (3 * 86_400)

      def clamp(time) = OfflineCopyWindow.clamp(time:, issued_at: ISSUED, received_at: RECEIVED)

      test "une heure dans la fenêtre est gardée" do
        inside = RECEIVED - 3600

        assert_equal inside, clamp(inside)
      end

      test "une heure future est ramenée à la réception" do
        assert_equal RECEIVED, clamp(RECEIVED + 3600)
      end

      test "une heure avant l'émission du paquet est ramenée à l'émission" do
        assert_equal ISSUED, clamp(ISSUED - 60)
      end

      test "jamais plus de 30 jours avant la réception, même si le paquet est plus ancien" do
        old_issue = RECEIVED - (40 * 86_400)
        floor = RECEIVED - OfflineCopyWindow::MAX_AGE

        assert_equal floor, OfflineCopyWindow.clamp(time: old_issue, issued_at: old_issue, received_at: RECEIVED)
        assert_equal floor, OfflineCopyWindow.clamp(time: RECEIVED - (31 * 86_400), issued_at: old_issue, received_at: RECEIVED)
      end

      test "un paquet émis après la réception (horloge serveur) ne retourne jamais une borne inversée" do
        assert_equal RECEIVED, OfflineCopyWindow.clamp(time: RECEIVED - 10, issued_at: RECEIVED + 10, received_at: RECEIVED)
      end

      test "pas d'heure : la réception" do
        assert_equal RECEIVED, clamp(nil)
      end

      test "bounds donne le plancher et le plafond" do
        assert_equal [ ISSUED, RECEIVED ], OfflineCopyWindow.bounds(issued_at: ISSUED, received_at: RECEIVED)
      end
    end
  end
end
