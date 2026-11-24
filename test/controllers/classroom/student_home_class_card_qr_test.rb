require "test_helper"

# CA-11 (ADR adresse-publique-etablissement §7) : la carte de classe porte le QR (SVG) de l'adresse de l'établissement, plus
# le sigle ; l'adresse ne contient ni jeton de classe ni identifiant d'élève.
class Classroom::StudentHomeClassCardQrTest < ActionDispatch::IntegrationTest
  include Classroom::JoinQrHelper

  setup do
    @classroom = create_classroom(name: "Tle D 1")
    @student = create_student(classroom: @classroom)
  end

  test "CA-11: the class card carries the QR of the school address, and no sigle" do
    @classroom.school.update!(sigle: "CM1T")
    sign_in_as @student

    get student_home_path

    assert_select "section#student_class_card" do
      assert_select "#student_school_qr[aria-hidden=true] svg"
      assert_select "#student_school_sigle", false
      # Retouche accueil-eleve-scanner-qr : « Scanner » et l'appareil photo dans le cadre du QR, en bas ; une indication cachée aux lecteurs d'écran.
      assert_select "button.ring-2 > #student_school_qr + span#student_school_qr_hint[aria-hidden=true]", text: I18n.t("classroom.student_homes.class_card.scan") do
        assert_select "svg"
      end
    end
  end

  # UDR accueil-eleve-qr-agrandi CA-1, CA-3 : le cadre du QR est un bouton nommé qui ouvre la fenêtre du QR en grand ;
  # le partage WhatsApp n'envoie que l'adresse publique de l'établissement, ni jeton de classe ni identifiant d'élève.
  test "CA-1: the QR frame is a named button opening the large QR dialog" do
    sign_in_as @student

    get student_home_path

    school = @classroom.school.name
    assert_select "section#student_class_card" do
      assert_select "button#student_school_qr_button[type=button][aria-haspopup=dialog][aria-controls=student_school_qr_dialog][aria-label=?]",
                    I18n.t("classroom.student_homes.class_card.qr_open_label", school:)
      assert_select "dialog#student_school_qr_dialog.dialog-phone-full:not([open])[aria-describedby=student_school_qr_dialog_hint]" do
        assert_select "#student_school_qr_dialog-title", text: I18n.t("classroom.student_homes.class_card.qr_dialog.title")
        assert_select "#student_school_qr_large[role=img][aria-label=?] svg", I18n.t("classroom.student_homes.class_card.qr_label", school:)
        assert_select "#student_school_qr_dialog_hint", text: I18n.t("classroom.student_homes.class_card.qr_dialog.hint")
      end
    end
  end

  test "CA-3: the WhatsApp share carries the school address only" do
    sign_in_as @student

    get student_home_path

    link = css_select("a#student_school_qr_whatsapp").first
    assert link, "the WhatsApp share link is missing"
    assert_equal "_blank", link["target"]
    text = CGI.unescape(link["href"].delete_prefix("https://wa.me/?text="))
    assert_equal I18n.t("classroom.student_homes.class_card.qr_dialog.whatsapp_message", school: @classroom.school.name,
                        url: school_signup_link_url(@classroom.school.public_id, host: "www.example.com")), text
    assert_not_includes text, @classroom.link_token.to_s
    assert_not_includes text, @student.public_id.to_s
  end

  test "CA-11: the QR encodes the school address only, no class token and no student identifier" do
    url = school_signup_link_url(@classroom.school.public_id, host: "www.example.com")

    assert_match %r{/ecole/#{@classroom.school.public_id}\z}, url
    assert_not_includes url, @classroom.link_token.to_s
    assert_not_includes url, @student.public_id.to_s
    assert_includes school_signup_qr_svg(@classroom.school.public_id), "<svg"
  end
end
