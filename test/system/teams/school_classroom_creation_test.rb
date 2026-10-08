require "application_system_test_case"

# CL-01, CL-04, UDR-0006, UDR-0031, UDR-0054: from a school's page, the team adds a classroom in the modal. A name already taken
# reopens the modal with its error; the created classroom is toasted with its join code in capitals and appears on the
# page, without a page reload.
class Teams::SchoolClassroomCreationTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands. A merged
  # controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true, formats: :html) })
  end

  setup do
    referential = seed_referential
    @school = create_school(name: "Lycée Classique d'Abidjan", school_type: "public", cycle: "both")
    create_classroom(school: @school, level: referential[:levels]["tle"], series: referential[:series]["d"], name: "Tle D 1")
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def tc(key, **) = I18n.t("teams.school_classrooms.#{key}", **)
  def error(field, kind) = I18n.t("activemodel.errors.models.dtos/classroom/classroom_input.attributes.#{field}.#{kind}")

  test "CL-01, CL-04: a taken name stays in the modal, then the classroom is created and toasted with its code" do
    visit school_path(@school.public_id)

    assert_no_page_reload do
      open_in_modal(new_school_classroom_path(@school.public_id))

      # UDR-0054 §3.1, §3.3 : l'onglet porte le titre de la modale ; le focus est sur le nom de la classe.
      assert_title "Ajouter une classe · Équipe · Lnclass"
      within "turbo-frame#modal dialog#classroom-modal[open]" do
        assert_equal "classroom[name]", page.evaluate_script("document.activeElement.name")
        select "Tle", from: "classroom_level_slug"
        find("#classroom_series_slug optgroup[label='Tle'] option[value='d']").select_option
        fill_in "classroom_name", with: "Tle D 1"
        click_on tc("new.submit")

        assert_selector "#classroom_name_error", text: error(:name, :taken)
        assert_field "classroom_name", with: "Tle D 1"

        fill_in "classroom_name", with: "Tle D 7"
        click_on tc("new.submit")
      end

      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_title "Lycée Classique d'Abidjan · Équipe · Lnclass"
      classroom = Orm::Classroom.find_by!(name: "Tle D 7")
      assert_toast tc("create.created", name: "Tle D 7")
      assert_selector "[id='classroom_#{classroom.public_id}']", text: "Tle D 7"
    end
  end
end
