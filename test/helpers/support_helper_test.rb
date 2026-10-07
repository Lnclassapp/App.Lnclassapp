require "test_helper"

# UDR-0061 §3.4 : la carte d'aide montre la FAQ, toujours, puis WhatsApp et l'appel seulement si leur numéro est
# configuré (config/support.yml, lu par config.x.support). Une clé vide supprime sa ligne.
class SupportHelperTest < ActionView::TestCase
  FULL = { phone: "2250700000001", whatsapp: "2250700000000", hours: "Lun.–ven., 08:00–18:00",
           whatsapp_reply: "Réponse en moins d'une heure" }.freeze

  def keys(support) = support_contacts(support).map(&:key)
  def contact(support, key) = support_contacts(support).find { it.key == key }

  test "with every value, the card lists the FAQ, WhatsApp and the call, in this order" do
    assert_equal %i[faq whatsapp call], keys(FULL)
  end

  test "the FAQ leads to /aide, WhatsApp to wa.me in a new tab, the call to tel:" do
    assert_equal help_path, contact(FULL, :faq).href
    assert_equal "https://wa.me/2250700000000", contact(FULL, :whatsapp).href
    assert contact(FULL, :whatsapp).external
    assert_equal "tel:+2250700000001", contact(FULL, :call).href
    assert_not contact(FULL, :call).external
  end

  test "the grey lines show the hours and the reply delay, never a number" do
    assert_equal "Les réponses aux questions les plus posées", contact(FULL, :faq).hint
    assert_equal "Lun.–ven., 08:00–18:00 · Réponse en moins d'une heure", contact(FULL, :whatsapp).hint
    assert_equal "Lun.–ven., 08:00–18:00", contact(FULL, :call).hint
  end

  test "a line whose number is missing is not rendered; the FAQ always is" do
    assert_equal %i[faq call], keys(FULL.merge(whatsapp: ""))
    assert_equal %i[faq whatsapp], keys(FULL.merge(phone: nil))
    assert_equal %i[faq], keys({})
  end

  test "without hours nor reply delay, WhatsApp keeps a short grey line and the call has none" do
    support = FULL.merge(hours: "", whatsapp_reply: "")

    assert_equal "Réponse par message", contact(support, :whatsapp).hint
    assert_nil contact(support, :call).hint
  end

  # Porteur, 2026-10-02 : WhatsApp et appel au 05 84 25 80 85, de 8h à 20h, sans délai de réponse annoncé.
  test "the production support offers the three lines, at wa.me/2250584258085 and tel:+2250584258085, from 8h to 20h" do
    production = Rails.application.config_for(:support, env: "production")

    assert_equal %i[faq whatsapp call], keys(production)
    assert_equal "https://wa.me/2250584258085", contact(production, :whatsapp).href
    assert_equal "tel:+2250584258085", contact(production, :call).href
    assert_equal "8h à 20h", contact(production, :whatsapp).hint
    assert_equal "8h à 20h", contact(production, :call).hint
  end

  test "by default, the helper reads config.x.support" do
    assert_equal %i[faq whatsapp call], support_contacts.map(&:key)
  end
end
