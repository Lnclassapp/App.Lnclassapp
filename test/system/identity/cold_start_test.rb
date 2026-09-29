require "application_system_test_case"

# CP-11 to CP-14 (ADR-0063, UDR-0050): a teacher whose school has no code for them signs up by its national code (or by
# the DRENA list), waits on the pending screen, and is validated by a colleague who vouches for them — or by the team,
# from the school page. On a desktop and on a 390 px phone.
class Identity::ColdStartTest < ApplicationSystemTestCase
  PENDING = "identity.pending_accounts.show.join_request".freeze
  SIGNUP = "identity.teacher_registrations".freeze

  setup do
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan", national_code: "012345")
    create_material(name: "SVT", shortname: "SVT")
  end

  def fill_person(contact: "05 01 02 03 04")
    fill_in "teacher_registration[last_name]", with: "Koné"
    fill_in "teacher_registration[first_name]", with: "Awa"
    choose I18n.t("genders.female")
    fill_in "teacher_registration[contact]", with: contact
    select "SVT", from: "teacher_registration[material_slug]"
    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: "4821"
  end

  def sign_up_by_national_code
    visit new_teacher_registration_path
    click_on I18n.t("#{SIGNUP}.form.no_school_code")
    assert_selector "h2", text: I18n.t("#{SIGNUP}.new.pending_title")
    fill_person
    fill_in "teacher_registration[national_code]", with: "012 345"
    growth_shot("1280-inscription-sans-code")
    click_on I18n.t("#{SIGNUP}.form.submit")
    assert_selector "#pending_account", text: I18n.t("#{PENDING}.pending.title")
  end

  test "CP-11, CP-13: by the national code, then held on the pending screen, then vouched by a colleague" do
    sponsor = create_teacher(school: @school, first_name: "Yao")
    sign_up_by_national_code

    assert_text "Lycée Classique d'Abidjan"
    growth_shot("1280-compte-en-attente")
    visit courses_path
    assert_current_path pending_account_path
    sign_out

    sign_in_as sponsor
    visit teacher_home_path
    within "#pending_colleagues" do
      assert_text "Awa Koné"
      growth_shot("1280-collegues-en-attente", scroll_to: "#pending_colleagues")
      click_on I18n.t("classroom.teacher_homes.pending_colleagues.vouch")
    end
    assert_toast I18n.t("school.join_request_vouches.create.done", name: "Awa Koné")
    assert_no_selector "#pending_colleagues"
    teacher = Orm::User.find_by!(contact: "0501020304")
    assert_equal [ sponsor.id ], Orm::Referral.where(referee: teacher).pluck(:referrer_id)
    sign_out

    sign_in_as teacher, pin: "4821"
    assert_current_path teacher_classrooms_path
  end

  test "CP-11: by the DRENA then the school, when the national code is not known" do
    visit new_pending_teacher_registration_path
    fill_person
    select "Abidjan 1", from: "teacher_registration[drena_public_id]"
    select "Lycée Classique d'Abidjan", from: "teacher_registration[school_public_id]"
    click_on I18n.t("#{SIGNUP}.form.submit")

    assert_selector "#pending_account", text: "Lycée Classique d'Abidjan"
    assert_equal [ @school.id ], Orm::SchoolJoinRequest.pluck(:school_id)
  end

  test "CP-12: the team validates one pending teacher and refuses another from the school page" do
    awa = create_teacher(school: nil, first_name: "Awa", last_name: "Koné")
    koffi = create_teacher(school: nil, first_name: "Koffi", last_name: "Yao")
    create_join_request(school: @school, teacher: awa)
    koffi_request = create_join_request(school: @school, teacher: koffi)
    sign_in_as create_team_member
    visit school_path(@school.public_id)

    within("#school_join_requests") { assert_text "Awa Koné" }
    growth_shot("1280-fiche-enseignants-en-attente", scroll_to: "#school_join_requests")
    within("#join_request_#{Orm::SchoolJoinRequest.find_by!(teacher: awa).public_id}") do
      click_on I18n.t("teams.schools.join_requests.approve")
    end
    assert_toast I18n.t("teams.join_requests.update.approved", name: "Awa Koné")

    within("#join_request_#{koffi_request.public_id}") { click_on I18n.t("teams.schools.join_requests.reject") }
    within("dialog[open]") { click_on I18n.t("teams.schools.join_requests.confirm_reject") }
    assert_toast I18n.t("teams.join_requests.update.rejected", name: "Koffi Yao")
    assert_no_selector "#school_join_requests"
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher: awa).pluck(:school_id)
    assert_equal "rejected", koffi_request.reload.status
  end

  test "CP-11: on a 390 px phone, the sign-up without code and the pending screen fit the width" do
    with_mobile_viewport do
      visit new_pending_teacher_registration_path
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "le formulaire déborde en largeur"
      fill_person
      fill_in "teacher_registration[national_code]", with: "012345"
      growth_shot("390-inscription-sans-code", desktop: false)
      click_on I18n.t("#{SIGNUP}.form.submit")

      assert_selector "#pending_account", text: I18n.t("#{PENDING}.pending.title")
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "l'écran d'attente déborde en largeur"
      growth_shot("390-compte-en-attente", desktop: false)
    end
  end
end
