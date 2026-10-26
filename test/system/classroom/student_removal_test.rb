require "application_system_test_case"

# IL-14, IL-15, IL-16 (ADR-0085 §4.3, §4.5, UDR-0081 §3.5, §3.7), end to end in a real browser: the teacher removes Koffi
# from the « 3e 2 »; Koffi keeps his account and lands on his home without a classroom, told once; the standard way
# refuses him the « 3e 2 » and lets him into the « 3e 3 »; the link of the « 3e 2 » takes him back, « Nouveau » again,
# and a second removal closes the standard way again.
class Classroom::StudentRemovalTest < ApplicationSystemTestCase
  ROSTER = "classroom.classrooms.roster".freeze
  FILE = "classroom.classroom_students.manage".freeze
  CHOICE = "classroom.student_classroom_choices.new".freeze
  CHOICE_ERRORS = "activemodel.errors.models.dtos/classroom/student_registration_input.attributes.base".freeze

  setup do
    drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena:, name: "Lycée Classique d'Abidjan")
    @level = create_level(name: "3ème")
    @classroom = create_classroom(school: @school, level: @level, name: "3e 2")
    @next_door = create_classroom(school: @school, level: @level, name: "3e 3")
    @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
    @koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "YAO", joined_at: 30.days.ago)
    create_student(classroom: @classroom, first_name: "Awa", last_name: "BAMBA", joined_at: 30.days.ago)
  end

  test "IL-14, IL-15: the teacher removes Koffi; Koffi lands home without a classroom, is refused the « 3e 2 », joins the « 3e 3 »" do
    sign_in_as @teacher
    remove_koffi

    sign_out
    sign_in_as @koffi

    assert_current_path student_home_path
    assert_text I18n.t("classroom.student_homes.show.removed")
    assert_selector "#student_next_step[data-state=no_classroom]"
    click_on I18n.t("classroom.student_homes.no_classroom.no_code")

    assert_current_path new_student_classroom_choice_path
    choose_classroom "3e 2"
    click_on I18n.t("#{CHOICE}.submit")

    assert_text I18n.t("#{CHOICE_ERRORS}.removed_from_classroom")
    assert_equal "Tu ne peux pas rejoindre cette classe. Demande son lien à ton enseignant.",
                 I18n.t("#{CHOICE_ERRORS}.removed_from_classroom")
    choose_classroom "3e 3"
    click_on I18n.t("#{CHOICE}.submit")

    assert_current_path student_home_path
    assert_selector "#student_next_step", text: /3e 3/i
    assert_equal [ @next_door.id ], Orm::ClassroomStudent.where(student: @koffi, left_at: nil).pluck(:classroom_id)
  end

  test "IL-16: the link of the « 3e 2 » takes Koffi back, « Nouveau » again; removed twice, the standard way refuses him again" do
    sign_in_as @teacher
    remove_koffi
    sign_out

    sign_in_as @koffi
    visit join_classroom_path(@classroom.reload.link_token)
    click_on I18n.t("classroom.joins.new.join_as_student")

    assert_current_path student_home_path
    assert_selector "#student_next_step", text: /3e 2/i
    sign_out

    sign_in_as @teacher
    visit classroom_path(@classroom.public_id)
    within("#student_#{@koffi.public_id}") { assert_text I18n.t("#{ROSTER}.new") }
    remove_koffi
    sign_out

    sign_in_as @koffi
    visit new_student_classroom_choice_path
    choose_classroom "3e 2"
    click_on I18n.t("#{CHOICE}.submit")

    assert_text I18n.t("#{CHOICE_ERRORS}.removed_from_classroom")
    assert_empty Orm::ClassroomStudent.where(student: @koffi, left_at: nil)
  end

  private

  # From the classroom page: Koffi's name opens his file (rapports-de-classe, memo Q4), « Retirer de la classe » there, then
  # the confirmation; back on the classroom page, the row is gone and the count drops.
  def remove_koffi
    visit classroom_path(@classroom.public_id)
    assert_selector "#classroom_roster_count", text: "2"
    within("#student_#{@koffi.public_id}") { find("a[href*='/students/']").click }
    click_on I18n.t("#{FILE}.remove")
    within("dialog#remove-student-#{@koffi.public_id}") { click_on I18n.t("#{FILE}.remove_confirm") }

    assert_current_path classroom_path(@classroom.public_id)
    assert_toast I18n.t("#{ROSTER}.removed", name: "Koffi YAO")
    assert_no_selector "#student_#{@koffi.public_id}"
    assert_selector "#classroom_roster_count", text: "1"
  end

  # UDR-0091 §3.1 : l'établissement de la dernière classe, replié ; le niveau en pastille, la classe en case.
  def choose_classroom(name)
    assert_selector "#class-picker-school-summary", text: "Lycée Classique d'Abidjan"
    within("turbo-frame#picker_levels") { choose "3ème" }
    within("turbo-frame#picker_classrooms") { choose name }
  end
end
