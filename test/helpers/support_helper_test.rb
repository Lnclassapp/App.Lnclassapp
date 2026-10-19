require "test_helper"

# UDR-0061 §3.4 : la carte d'aide montre la FAQ, toujours, puis WhatsApp et l'appel seulement si leur numéro est
# configuré (config/support.yml, lu par config.x.support). Une clé vide supprime sa ligne. UDR-0128 (amendement de
# l'UDR-0061 §3.4) : le lien WhatsApp porte un message prêt qui présente la personne connectée, encodé dans ?text=.
class SupportHelperTest < ActionView::TestCase
  About = Queries::Identity::ShellUserQuery::About
  WA = "https://wa.me/2250700000000?text=".freeze
  PLAIN = "Bonjour%20Lnclass%2C%20ma%20question%20%3A%20".freeze
  FULL = { phone: "2250700000001", whatsapp: "2250700000000", hours: "Lun.–ven., 08:00–18:00",
           whatsapp_reply: "Réponse en moins d'une heure" }.freeze

  def keys(support) = support_contacts(support).map(&:key)
  def contact(support, key, user: nil) = support_contacts(support, user:).find { it.key == key }
  def text_of(user) = URI.decode_www_form_component(contact(FULL, :whatsapp, user:).href.delete_prefix(WA))

  def account(role, about: About.new(gender: "female"), name: "Awa Koné")
    NavigationHelper::ShellUser.new(name:, role:, public_id: "ELV-7K2M9Q", about:)
  end

  test "with every value, the card lists the FAQ, WhatsApp and the call, in this order" do
    assert_equal %i[faq whatsapp call], keys(FULL)
  end

  test "the FAQ leads to /aide, WhatsApp to wa.me in a new tab, the call to tel:" do
    assert_equal help_path, contact(FULL, :faq).href
    assert_equal "#{WA}#{PLAIN}", contact(FULL, :whatsapp).href
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
    assert_equal "https://wa.me/2250584258085?text=#{PLAIN}", contact(production, :whatsapp).href
    assert_equal "tel:+2250584258085", contact(production, :call).href
    assert_equal "8h à 20h", contact(production, :whatsapp).hint
    assert_equal "8h à 20h", contact(production, :call).hint
  end

  test "by default, the helper reads config.x.support" do
    assert_equal %i[faq whatsapp call], support_contacts.map(&:key)
  end

  # UDR-0128 §3.1 : élève connecté — nom, rôle et classe, établissement ; rien d'autre.
  test "a signed-in student gets a message with their name, classroom and school" do
    about = About.new(gender: "female", classroom: "Tle D 1", school: "Lycée moderne de Cocody")

    assert_equal "Bonjour Lnclass, je suis Awa Koné, élève de Tle D 1, Lycée moderne de Cocody. Ma question : ",
                 text_of(account(:student, about:))
  end

  test "a student without an active classroom is introduced as a student, without classroom nor school" do
    assert_equal "Bonjour Lnclass, je suis Awa Koné, élève. Ma question : ", text_of(account(:student))
  end

  # UDR-0128 §3.1 : « enseignant » ou « enseignante » selon le genre du compte, sa matière, son établissement principal.
  test "a teacher gets a message with their name, subject and school, agreed with their gender" do
    about = ->(gender) { About.new(gender:, material: "Mathématiques", school: "Lycée moderne de Cocody") }

    assert_equal "Bonjour Lnclass, je suis Awa Koné, enseignante de Mathématiques, Lycée moderne de Cocody. Ma question : ",
                 text_of(account(:teacher, about: about.("female")))
    assert_equal "Bonjour Lnclass, je suis Yao Kouassi, enseignant de Mathématiques, Lycée moderne de Cocody. Ma question : ",
                 text_of(account(:teacher, name: "Yao Kouassi", about: about.("male")))
  end

  test "a teacher without subject nor primary school keeps the role alone" do
    assert_equal "Bonjour Lnclass, je suis Yao Kouassi, enseignant. Ma question : ",
                 text_of(account(:teacher, name: "Yao Kouassi", about: About.new(gender: "male")))
  end

  # UDR-0128 §3.1 : la fonction n'est pas enregistrée ; « membre de la direction » et l'établissement.
  test "a school admin gets a message with their name, the direction and the school" do
    about = About.new(gender: "male", school: "Collège Notre-Dame")

    assert_equal "Bonjour Lnclass, je suis Koffi Yao, membre de la direction, Collège Notre-Dame. Ma question : ",
                 text_of(account(:school_admin, name: "Koffi Yao", about:))
  end

  # UDR-0128 §3.1 : aucun identifiant, même public (ADR-0029) : le nom et l'établissement suffisent au support.
  test "the message never carries an identifier, even the public one" do
    about = About.new(gender: "female", classroom: "Tle D 1", school: "Lycée moderne de Cocody")

    %i[student teacher school_admin].each do |role|
      text = text_of(account(role, about:))
      assert_not_includes text, "ELV-7K2M9Q", role
      assert_not_includes text, "identifiant", role
    end
  end

  test "a team member, a visitor and a shell without data get the plain message" do
    plain = "Bonjour Lnclass, ma question : "

    assert_equal plain, text_of(account(:team))
    assert_equal plain, text_of(nil)
    assert_equal plain, text_of(account(:student, about: nil))
  end

  # UDR-0128 §3.2 : un seul paramètre text, encodé en pourcent (espace %20, apostrophe %27, accents en UTF-8) ;
  # le texte décodé est celui d'origine.
  test "accents, apostrophes and ampersands are percent-encoded, and decode back to the same message" do
    about = About.new(gender: "female", classroom: "1ère A", school: "Lycée d'Abidjan & Co")
    href = contact(FULL, :whatsapp, user: account(:student, name: "Ahou N'Guessan", about:)).href
    query = href.delete_prefix(WA)

    assert_match %r{\Ahttps://wa\.me/2250700000000\?text=[A-Za-z0-9%._~-]+\z}, href
    assert_includes query, "N%27Guessan"
    assert_includes query, "1%C3%A8re"
    assert_includes query, "%20%26%20Co"
    assert_equal "Bonjour Lnclass, je suis Ahou N'Guessan, élève de 1ère A, Lycée d'Abidjan & Co. Ma question : ",
                 URI.decode_www_form_component(query)
  end
end
