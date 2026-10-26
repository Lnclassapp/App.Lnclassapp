require "application_system_test_case"

# ID-01, ID-02, ID-09 (ADR-0077, UDR-0070 §3.1, §3.2): from the homepage, at 390 px and without horizontal scroll, a
# visitor follows one of the three entries to the direction registration, registers with the code of their school and
# lands on « Travail des élèves » with the toast; the fourth account by the code reads the refusal of the cap. ED-11
# (ADR-0092, UDR-0092 §3.1): « Votre fonction » is chosen with the rest, and the « Direction » block reads it.
class Identity::SchoolStaffRegistrationTest < ApplicationSystemTestCase
  FORM = "identity.school_staff_registrations.form".freeze
  ERRORS = "activemodel.errors.models.dtos/identity/school_staff_registration_input.attributes".freeze

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
  end

  # Lot F (CA-A2) : l'entrée de la direction est « Espace établissement », une fenêtre qui n'existe que drapeau allumé.
  test "ID-09, ID-01: at 390 px, « Espace établissement » leads to the registration; the direction lands on its home" do
    pilot_flags!(school_space_enabled: true)
    with_mobile_viewport do
      visit root_path
      assert no_horizontal_scroll?, "la page d'accueil défile en largeur à 390 px"

      click_on I18n.t("homepage.role_modal.school.trigger")
      within("dialog#role-modal-school-entry[open]") { click_on I18n.t("homepage.role_modal.school.sign_up") }
      assert_current_path new_school_staff_registration_path
      assert no_horizontal_scroll?, "la page d'inscription défile en largeur à 390 px"

      fill_registration(school_code: "k7m 4qz")
      click_on I18n.t("#{FORM}.submit")

      assert_toast I18n.t("identity.school_staff_registrations.create.created")
      assert_current_path school_admin_classrooms_path
      assert_selector "h1", text: /\ABonjour, /
      assert_selector "#direction_home_school"
      assert no_horizontal_scroll?, "l'accueil de la direction défile en largeur à 390 px"
    end
    admin = Orm::User.find_by!(contact: "0701020304", role: "school_admin")
    assert_equal [ [ @school.id, "code", "secretary" ] ], Orm::SchoolStaff.where(user: admin).pluck(:school_id, :joined_via, :position)
  end

  test "ID-02: the fourth account by the code reads the refusal of the cap, without reloading, and no account exists" do
    3.times { create_school_admin(school: @school, joined_via: "code") }

    visit new_school_staff_registration_path
    assert_no_page_reload do
      fill_registration
      click_on I18n.t("#{FORM}.submit")

      assert_selector "#school-staff-registration-form [role=alert]", text: I18n.t("#{ERRORS}.base.cap_reached")
    end
    assert_current_path school_staff_registrations_path
    assert_field "school_staff_registration[last_name]", with: "Kouassi"
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  private

  def no_horizontal_scroll? = evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")

  def fill_registration(school_code: "K7M-4QZ")
    fill_in "school_staff_registration[last_name]", with: "Kouassi"
    fill_in "school_staff_registration[first_name]", with: "Aya Marie"
    find("label", text: I18n.t("genders.female")).click
    fill_in "school_staff_registration[contact]", with: "07 01 02 03 04"
    fill_in "school_staff_registration[school_code]", with: school_code
    find("label", text: I18n.t("shared.staff_positions.secretary")).click
    fill_in "school_staff_registration[pin]", with: "4821"
    fill_in "school_staff_registration[pin_confirmation]", with: "4821"
  end
end
