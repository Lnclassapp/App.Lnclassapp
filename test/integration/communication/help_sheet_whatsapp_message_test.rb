require "test_helper"

# UDR-0128 (aide-whatsapp-message-pret, CA-1 à CA-5) : la ligne WhatsApp de la carte d'aide ouvre une conversation avec
# un message prêt qui présente la personne connectée (nom, rôle, établissement) ; un visiteur reçoit le message simple.
# Le message ne porte jamais le numéro de la personne (WhatsApp le transmet déjà), ni son PIN, ni un code, ni un
# identifiant. Les données viennent de la lecture du shell déjà faite pour l'en-tête : aucune requête de plus
# (test/infrastructure/queries/identity/shell_user_query_test.rb). La direction reçoit la carte dans son en-tête
# (UDR-0128 §3.4) ; l'équipe, non.
class Communication::HelpSheetWhatsappMessageTest < ActionDispatch::IntegrationTest
  WA = "https://wa.me/2250700000000?text=".freeze
  LINK = "dialog#help-sheet a#help-sheet-whatsapp[target=_blank][rel~=noopener]".freeze

  # Le texte décodé du lien WhatsApp de la carte, tel que WhatsApp l'écrit dans la conversation.
  def whatsapp_message
    href = css_select(LINK).sole["href"]
    assert href.start_with?(WA), href
    URI.decode_www_form_component(href.delete_prefix(WA))
  end

  def assert_no_secret(user, message)
    assert_not_includes message, user.contact
    assert_not_includes message, user.public_id
    assert_not_includes message, "2468"
    assert_no_match(/\d{4,}/, message)
  end

  test "CA-1: a signed-in student opens WhatsApp with a message giving their name, classroom and school" do
    classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée moderne de Cocody"))
    student = create_student(classroom:, first_name: "Awa", last_name: "Koné")
    sign_in_as student

    get student_home_path

    assert_response :success
    message = whatsapp_message
    assert_equal "Bonjour Lnclass, je suis Awa Koné, élève de Tle D 1, Lycée moderne de Cocody. Ma question : ",
                 message
    assert_no_secret student, message
  end

  test "CA-2: a signed-in teacher opens WhatsApp with their name, subject and school" do
    teacher = create_teacher(school: create_school(name: "Lycée d'Abidjan"), material: create_material(name: "Physique-Chimie"),
                             first_name: "Yao", last_name: "N'Guessan", gender: "male")
    sign_in_as teacher

    get teacher_home_path

    assert_response :success
    message = whatsapp_message
    assert_equal "Bonjour Lnclass, je suis Yao N'Guessan, enseignant de Physique-Chimie, Lycée d'Abidjan. Ma question : ",
                 message
    assert_no_secret teacher, message
  end

  test "CA-3: a visitor on the sign-in and the student sign-up pages gets the plain message" do
    [ new_session_path, new_student_registration_path ].each do |path|
      get path

      assert_response :success
      assert_equal "Bonjour Lnclass, ma question : ", whatsapp_message, path
    end
  end

  test "CA-4: the direction opens WhatsApp with their name, the direction and their school" do
    admin = create_school_admin(school: create_school(name: "Collège Notre-Dame"), first_name: "Koffi", last_name: "Yao")
    sign_in_as admin

    get school_admin_classrooms_path

    assert_response :success
    message = whatsapp_message
    assert_equal "Bonjour Lnclass, je suis Koffi Yao, membre de la direction, Collège Notre-Dame. Ma question : ", message
    assert_no_secret admin, message
  end

  test "CA-4: the team has no help sheet in its header, so no prefilled link" do
    sign_in_as create_team_member

    get team_home_path

    assert_response :success
    assert_select "a[href^='https://wa.me/2250700000000']", 0
  end
end
