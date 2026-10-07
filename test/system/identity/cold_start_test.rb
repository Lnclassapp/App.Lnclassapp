require "application_system_test_case"

# CP-11, CP-14 (ADR-0063, UDR-0050), rewritten by ADR-0082 §4.3 and UDR-0078: a teacher whose school has never used
# Lnclass signs up on /teacher-signup by the DRENA, then the school, with a full name. They are attached at once, without
# any request, and land on picking their classes. CP-12, CP-13: a request still pending from before the pause is validated
# by a colleague who vouches for them — or by the team, from the school page. On a desktop and on a 390 px phone.
class Identity::ColdStartTest < ApplicationSystemTestCase
  SIGNUP = "identity.teacher_registrations".freeze

  setup do
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan")
    create_material(name: "SVT", shortname: "SVT")
  end

  def sign_up(shot:, desktop: true)
    visit new_teacher_registration_path
    yield if block_given?
    assert_field "teacher_registration[contact]", placeholder: "0701020304"
    select "Abidjan 1", from: "teacher_registration[drena_public_id]"
    select "Lycée Classique d'Abidjan", from: "teacher_registration[school_public_id]"
    select "SVT", from: "teacher_registration[material_slug]"
    fill_in "teacher_registration[last_name]", with: "KONÉ"
    fill_in "teacher_registration[first_name]", with: "Awa"
    choose I18n.t("genders.female")
    fill_in "teacher_registration[contact]", with: "0501020304"
    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: "4821"
    growth_shot(shot, desktop:)
    click_on I18n.t("#{SIGNUP}.form.submit")
    assert_toast I18n.t("#{SIGNUP}.create.welcome")
    assert_current_path teacher_classrooms_path
  end

  test "ADR-0082 §4.3: by the DRENA then the school, the teacher is attached at once, without a request, and reaches the catalogue" do
    sign_up(shot: "1280-inscription-drena")

    visit courses_path
    assert_current_path courses_path
    teacher = Orm::User.find_by!(contact: "0501020304")
    assert_equal [ "KONÉ", "Awa" ], [ teacher.last_name, teacher.first_name ]
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher:).pluck(:school_id, :primary)
    assert_equal "standard", Orm::TeacherProfile.find_by!(user: teacher).joined_via
    assert_not Orm::SchoolJoinRequest.exists?
  end

  test "CP-13: a request pending from before the pause is vouched by a colleague" do
    sponsor = create_teacher(school: @school, first_name: "Yao")
    awa = create_teacher(school: nil, first_name: "Awa", last_name: "Koné", contact: "0501020304")
    create_join_request(school: @school, teacher: awa)

    sign_in_as sponsor
    visit teacher_home_path
    within "#pending_colleagues" do
      assert_text "Awa Koné"
      growth_shot("1280-collegues-en-attente", scroll_to: "#pending_colleagues")
      click_on I18n.t("classroom.teacher_homes.pending_colleagues.vouch")
    end
    assert_toast I18n.t("school.join_request_vouches.create.done", name: "Awa Koné")
    assert_no_selector "#pending_colleagues"
    assert_equal [ sponsor.id ], Orm::Referral.where(referee: awa).pluck(:referrer_id)
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher: awa).pluck(:school_id)
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

  test "CP-11: on a 390 px phone, the sign-up and the page that follows fit the width" do
    with_mobile_viewport do
      sign_up(shot: "390-inscription-drena", desktop: false) do
        assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
               "le formulaire déborde en largeur"
      end

      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page qui suit l'inscription déborde en largeur"
    end
  end
end
