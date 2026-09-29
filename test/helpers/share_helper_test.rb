require "test_helper"

# CP-05, CP-08 (UDR-0050): the share links carry a ready message, percent-encoded, to WhatsApp and to the SMS app.
class ShareHelperTest < ActionView::TestCase
  test "the WhatsApp link opens wa.me with the message" do
    assert_equal "https://wa.me/?text=Bonjour%20%21%20https%3A%2F%2Fx.test%2Fe%2Fk7m4qz%3Fref%3Dab",
                 whatsapp_share_url("Bonjour ! https://x.test/e/k7m4qz?ref=ab")
  end

  test "the SMS link opens the SMS app with the message as body" do
    assert_equal "sms:?body=L%27%C3%A9cole", sms_share_url("L'école")
  end
end
