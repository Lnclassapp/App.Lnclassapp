require "application_system_test_case"

# ME-01, ME-07, ME-08 (ADR-0094, UDR-0098 §3.1, UDR-0099 §3.4), in a real browser: at 390 px, the account panel of a
# teacher of two schools lists them, the current one checked; touching the other moves the whole space there. On a
# computer, the direction's link of a third school, opened signed in, asks to join it, and one click attaches it.
class School::SeveralSchoolsTest < ApplicationSystemTestCase
  setup do
    @a = create_school(name: "Lycée moderne d'Abobo")
    @b = create_school(name: "Collège Saint-Michel")
    sixth = create_level(name: "6ème", position: 1)
    @teacher = create_teacher(school: @a, first_name: "Ibrahim", last_name: "Koné",
                              classrooms: [ create_classroom(school: @a, level: sixth, name: "6ème 1"),
                                            create_classroom(school: @b, level: create_level(name: "4ème", position: 3), name: "4ème 2") ])
    add_teacher_school(@teacher, @b)
  end

  def tn(key, **) = I18n.t("shared.navigation.account_panel.schools.#{key}", **)

  test "ME-07, ME-08: at 390 px, the panel lists both schools; touching B moves the home to B" do
    sign_in_as @teacher

    with_mobile_viewport do
      visit teacher_home_path
      assert_selector "main", text: /6ème 1/i # l'en-tête de la carte est en capitales
      assert_no_selector "main", text: /4ème 2/i

      find("header.teacher-band a[href='#{teacher_menu_path}']").click
      within("#teacher_menu #account_schools") do
        assert_selector "button[aria-current=true][disabled]", text: "Lycée moderne d'Abobo"
        find("button[aria-label=\"#{tn("switch", school: "Collège Saint-Michel")}\"]").click
      end

      assert_toast I18n.t("school.current_schools.update.done", school: "Collège Saint-Michel")
      assert_selector "main", text: /4ème 2/i
      assert_no_selector "main", text: /6ème 1/i
      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    end
  end

  test "ME-01: the direction's link of another school, opened signed in, asks to join it; one click attaches it" do
    third = create_school(name: "Collège Notre-Dame")
    sign_in_as @teacher

    visit teacher_invite_link_path(third.direction_invite_token)
    within("#join_school") do
      assert_text I18n.t("school.teacher_school_joins.new.confirm.title", school: "Collège Notre-Dame")
      click_on I18n.t("school.teacher_school_joins.new.confirm.join")
    end

    assert_toast I18n.t("school.teacher_schools.create.joined", school: "Collège Notre-Dame")
    assert_current_path teacher_classrooms_path
    assert_equal 3, Orm::TeacherSchool.where(teacher: @teacher).count
  end
end
