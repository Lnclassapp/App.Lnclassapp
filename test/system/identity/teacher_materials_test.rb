require "application_system_test_case"

# EPM-02, EPM-04, EPM-05 (ADR-0103 §4.4 amended, UDR-0125, UDR « écrans enseignant sans répétition » §3.9): a teacher signs
# up with « Physique-Chimie » only, then adds « SVT » and « Mathématiques » in « Mes matières », without reloading the page;
# an empty list is refused in the modal. The header then says his three short names next to his school.
class Identity::TeacherMaterialsTest < ApplicationSystemTestCase
  setup do
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Moderne de Cocody")
    create_material(name: "Physique-Chimie", shortname: "PC")
    create_material(name: "SVT", shortname: "SVT")
    create_material(name: "Mathématiques", shortname: "Maths")
  end

  def t(key, **) = I18n.t(key, **)

  test "sign up with one subject, then add two more in the profile" do
    visit new_teacher_registration_path
    select "Abidjan 1", from: "teacher_registration[drena_public_id]"
    select "Lycée Moderne de Cocody", from: "teacher_registration[school_public_id]"
    select "Physique-Chimie", from: "teacher_registration[material_slug]"
    fill_in "teacher_registration[last_name]", with: "KOUASSI"
    fill_in "teacher_registration[first_name]", with: "Yao"
    choose t("genders.male")
    fill_in "teacher_registration[contact]", with: "0501020304"
    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: "4821"
    click_on t("identity.teacher_registrations.form.submit")

    assert_current_path teacher_classrooms_path, wait: 20
    visit profile_path

    within("#profile_materials") { assert_text "Physique-Chimie" and assert_no_text "SVT" }
    assert_no_page_reload do
      find("#profile_materials a[aria-label='Modifier mes matières']").click
      within("dialog#profile-materials-modal") do
        uncheck "Physique-Chimie"
        click_on t("identity.profile_materials.edit.submit")

        assert_selector "#profile_materials_material_slugs_error", text: "Gardez au moins une matière."
        check "Physique-Chimie"
        check "SVT"
        check "Mathématiques"
        click_on t("identity.profile_materials.edit.submit")
      end

      assert_toast t("identity.profile_materials.update.updated")
      assert_no_selector "dialog#profile-materials-modal"
      assert_selector "#profile_materials dd", text: /Physique-Chimie\s*Mathématiques\s*SVT/
    end
    visit profile_path

    assert_selector "p.text-mute", text: "PC, Maths, SVT · Lycée Moderne de Cocody", visible: :all, minimum: 1
  end
end
