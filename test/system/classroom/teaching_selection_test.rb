require "application_system_test_case"

# CL-09, TR-08 replaced (UDR-0025): a teacher declares three classrooms and withdraws one — toggles and counter follow
# without reloading the page — meets the 422 of « Terminer » with no classroom, then finishes on the teacher home.
class Classroom::TeachingSelectionTest < ApplicationSystemTestCase
  # The teacher home belongs to Lot D3: until it is merged, a stand-in answers on its route, as in
  # test/system/teams/levels_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Classroom::TeacherHomesController")
    Classroom.const_set(:TeacherHomesController, Class.new(AuthenticatedController) { def show = render(html: "accueil", layout: true) })
  end

  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    sixth = create_level(name: "6ème", position: 1, cycle: "first")
    third = create_level(name: "3ème", position: 4, cycle: "first")
    @classrooms = [ [ sixth, "6ème 1" ], [ sixth, "6ème 2" ], [ third, "3ème B" ] ].to_h do |level, name|
      [ name, create_classroom(school:, level:, name:) ]
    end
    @teacher = create_teacher(school:, onboarded: false)
  end

  def tl(key, **) = I18n.t("classroom.teaching_selections.#{key}", **)
  def counter(count) = I18n.t("classroom.teachings.counter.count", count:)
  def toggle(name) = find("form#teaching_#{@classrooms.fetch(name).public_id} button")
  def declared_names = Orm::Classroom.joins(:teacher_classrooms).where(teacher_classrooms: { teacher_id: @teacher.id }).pluck(:name).sort

  test "declare three classrooms, withdraw one, then finish — the toggles and the counter follow without a reload" do
    sign_in_as @teacher
    assert_current_path teacher_classrooms_path
    assert_selector "h1", text: tl("index.title")
    assert_selector "#teaching_counter", text: counter(0)

    assert_no_page_reload do
      click_on tl("index.finish")
      assert_selector "#teacher-onboarding-error", text: I18n.t("classroom.teacher_onboardings.create.no_classroom")
    end

    assert_no_page_reload do
      [ "6ème 1", "6ème 2", "3ème B" ].each_with_index do |name, index|
        toggle(name).click
        assert_selector "form#teaching_#{@classrooms.fetch(name).public_id} button[aria-pressed=true]"
        assert_selector "#teaching_counter", text: counter(index + 1)
      end

      toggle("6ème 2").click
      assert_selector "form#teaching_#{@classrooms.fetch('6ème 2').public_id} button[aria-pressed=false]"
      assert_selector "#teaching_counter", text: counter(2)
    end
    assert_equal [ "3ème B", "6ème 1" ], declared_names

    click_on tl("index.finish")

    assert_current_path teacher_home_path
    assert_toast I18n.t("classroom.teacher_onboardings.create.completed")
    assert Orm::TeacherProfile.find_by!(user: @teacher).onboarding_completed_at
  end

  test "the same declaration on a 390 px screen" do
    with_mobile_viewport do
      sign_in_as @teacher

      assert_no_page_reload do
        toggle("3ème B").click
        assert_selector "#teaching_counter", text: counter(1)
      end
      click_on tl("index.finish")

      assert_current_path teacher_home_path
    end
  end
end
