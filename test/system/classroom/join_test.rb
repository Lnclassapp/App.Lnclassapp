require "application_system_test_case"

# IL-01, IL-02, IL-08, IL-09, IL-10 (ADR-0085, UDR-0081 §3.2 to §3.4), in a real browser: there is no classroom code any
# more (Lot F). A visitor signs up by the cascade DRENA → school → level → classroom, meets the 422 of an unconfirmed
# secret code without reloading the page, then lands home in the classroom (way « standard »); or opens a classroom link,
# sees the classroom already chosen and lands home in it (way « link »); « Ce n'est pas ta classe ? » goes back to the
# cascade (way « standard »). An old link /c/<code> and /join lead to the standard page, the first with the alert.
# IL-06 and IL-20 live in the browser: the submit button waits for a classroom, the number is cleaned while pasted and the
# secret code concordance shows before sending. UDR-0057: at 390 px, the link page keeps a single primary action.
class Classroom::JoinTest < ApplicationSystemTestCase
  FORM = "classroom.student_registrations.form".freeze
  JOINS = "classroom.joins.new".freeze
  ERRORS = "activemodel.errors.models.dtos/classroom/student_registration_input.attributes".freeze
  # Above the fold on /c/<token>: the left column (hidden under md), the logo and the card.
  JOIN_BLOCKS = "main > section:first-child, main > section:last-child > *".freeze

  setup do
    drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena:, name: "Lycée Classique d'Abidjan")
    @level = create_level(name: "6ème")
    @classroom = create_classroom(school: @school, level: @level, name: "6ème 1")
    @other = create_classroom(school: @school, level: @level, name: "6ème 2")
    create_school(drena:, name: "Collège sans classe")
  end

  test "IL-01, IL-06: the cascade, an unconfirmed secret code shown without reloading, then the arrival in the classroom" do
    visit new_student_registration_path

    # IL-06 : un établissement sans classe le dit, et « Créer mon compte » reste désactivé tant qu'aucune classe n'est cochée.
    select "Abidjan 1", from: "student_registration[drena_public_id]"
    select "Collège sans classe", from: "student_registration[school_public_id]"
    within("turbo-frame#picker_levels") { assert_text I18n.t("classroom.student_registrations.class_picker.not_found_title") }
    assert_button I18n.t("#{FORM}.submit"), disabled: true
    choose_classroom "6ème 1"
    assert_button I18n.t("#{FORM}.submit"), disabled: false
    sign_up_after_a_wrong_confirmation

    assert_equal [ [ @classroom.id, "standard" ] ], memberships_of_the_new_student
  end

  test "IL-08: the link shows the classroom already chosen, and the student lands in it, way « link », at 390 px" do
    with_mobile_viewport do
      visit join_classroom_path(@classroom.reload.link_token)

      assert_selector "#classroom-preview", text: "6ème 1 — Lycée Classique d'Abidjan"
      assert_no_selector "select[name='student_registration[drena_public_id]']"
      assert_no_text "6ème 2"
      sign_up_after_a_wrong_confirmation
    end

    assert_equal [ [ @classroom.id, "link" ] ], memberships_of_the_new_student
  end

  test "IL-10: « Ce n'est pas ta classe ? » goes back to the cascade, and the student lands in the other classroom" do
    visit join_classroom_path(@classroom.reload.link_token)
    click_on I18n.t("#{FORM}.other_classroom")

    assert_current_path new_student_registration_path
    assert_no_selector "#classroom-link-invalid"
    choose_classroom "6ème 2"
    sign_up

    assert_equal [ [ @other.id, "standard" ] ], memberships_of_the_new_student
  end

  test "IL-02, IL-09: /join and an old classroom code link lead to the standard page, the old link with the alert" do
    visit "/join"

    assert_current_path new_student_registration_path
    assert_no_selector "#classroom-link-invalid"

    visit join_classroom_path("kfm37")

    assert_current_path new_student_registration_path
    assert_selector "#classroom-link-invalid[role=alert]", text: I18n.t("#{FORM}.link_invalid")
    assert_selector "select[name='student_registration[drena_public_id]']"
    assert_no_selector "input[name*=code]"
  end

  test "at 390 px, a student without a classroom sees the preview and one button, the reassurance in an info tip" do
    sign_in_as create_student(classroom: create_classroom(status: "archived"))

    with_mobile_viewport do
      visit join_classroom_path(@classroom.reload.link_token)

      assert_selector "h1", text: I18n.t("#{JOINS}.student_title")
      assert_blocks_above_fold JOIN_BLOCKS, max: 5
      assert_single_primary_action scope: "main"
      assert_no_text I18n.t("#{JOINS}.student_info_tip")
      find("summary", text: I18n.t("components.info_tip.label", label: I18n.t("#{JOINS}.student_title")), visible: :all).click
      assert_text I18n.t("#{JOINS}.student_info_tip")
      click_on I18n.t("#{JOINS}.join_as_student")
    end

    assert_toast I18n.t("classroom.joins.create.welcome")
    assert_current_path student_home_path
  end

  private

  # Each list of the cascade arrives in its frame once its parent is chosen (UDR-0081 §3.3).
  def choose_classroom(name)
    select "Abidjan 1", from: "student_registration[drena_public_id]"
    select "Lycée Classique d'Abidjan", from: "student_registration[school_public_id]"
    select "6ème", from: "student_registration[level_slug]"
    within("turbo-frame#picker_classrooms") { choose name }
  end

  def fill_in_the_student(pin_confirmation: "4821")
    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    # IL-20 (IE-19) : le numéro collé est nettoyé en direct.
    paste "student_registration[contact]", "(+225) 07 01 02 03 04"
    assert_field "student_registration[contact]", with: "0701020304"
    fill_in "student_registration[pin]", with: "4821"
    fill_in "student_registration[pin_confirmation]", with: pin_confirmation
  end

  def sign_up
    fill_in_the_student
    click_on I18n.t("#{FORM}.submit")

    assert_toast I18n.t("classroom.student_registrations.create.welcome")
    assert_current_path student_home_path
  end

  def sign_up_after_a_wrong_confirmation
    assert_no_page_reload do
      fill_in_the_student(pin_confirmation: "1357")
      # IL-20 (IE-17) : la concordance du code secret se lit avant l'envoi ; le serveur refuse quand même.
      assert_selector "#pin_match_status.text-error", text: I18n.t("#{FORM}.pin_match.ko")
      click_on I18n.t("#{FORM}.submit")

      assert_selector "#student_registration_pin_confirmation_error", text: I18n.t("#{ERRORS}.pin_confirmation.confirmation")
    end
    assert_field "student_registration[last_name]", with: "KOUASSI"
    assert_equal 0, Orm::User.where(role: "student").count

    fill_in "student_registration[pin]", with: "4821"
    fill_in "student_registration[pin_confirmation]", with: "4821"
    assert_selector "#pin_match_status.text-success", text: I18n.t("#{FORM}.pin_match.ok")
    click_on I18n.t("#{FORM}.submit")

    assert_toast I18n.t("classroom.student_registrations.create.welcome")
    assert_current_path student_home_path
  end

  # Un collage : toute la valeur d'un coup, puis un seul événement input, comme le navigateur.
  def paste(field, text)
    execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }))",
                   find_field(field), text)
  end

  def memberships_of_the_new_student
    student = Orm::User.find_by!(contact: "0701020304", role: "student")
    Orm::ClassroomStudent.where(student:, left_at: nil).pluck(:classroom_id, :joined_via)
  end
end
