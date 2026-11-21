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
      assert_select "#student_school_qr svg"
      assert_select "#student_school_qr[role=img][aria-label=?]", I18n.t("classroom.student_homes.class_card.qr_label", school: @classroom.school.name)
      assert_select "#student_school_sigle", false
    end
  end

  test "CA-11: the QR encodes the school address only, no class token and no student identifier" do
    url = school_signup_link_url(@classroom.school.public_id, host: "www.example.com")

    assert_match %r{/e/#{@classroom.school.public_id}\z}, url
    assert_not_includes url, @classroom.link_token.to_s
    assert_not_includes url, @student.public_id.to_s
    assert_includes school_signup_qr_svg(@classroom.school.public_id), "<svg"
  end
end
