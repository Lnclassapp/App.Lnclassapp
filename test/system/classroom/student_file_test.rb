require "application_system_test_case"

# rapports-de-classe, Lot A (CL-13, AS-24 ; ADR-0097, UDR-0107) : l'enseignant ouvre la fiche d'Awa dans sa classe, la lit à
# 390 px sans défilement horizontal, lui donne un code de récupération, puis la retire de la classe depuis la fiche : retour à
# la page de la classe, avec le toast du retrait (memo Q4).
class Classroom::StudentFileTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT
  SCOPE = "classroom.classroom_students".freeze

  setup do
    school = create_school(name: "Lycée Moderne de Cocody")
    @classroom = create_classroom(school:, level: create_level(name: "3ème"), name: "3ème B")
    @teacher = create_teacher(school:, classrooms: [ @classroom ])
    @awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba", contact: "0712345604", joined_at: 1.month.ago)
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao", joined_at: 1.month.ago)
    svt = create_material(name: "SVT", category: "science")
    exercise = create_exercise(essential: create_essential(course: create_course(material: svt)), title: "La reproduction chez les plantes à fleurs")
    assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    [ 40, 85 ].each_with_index do |score, index|
      create_exercise_session(student: @awa, exercise:, status: "completed", score_percent: score, classroom_assignment: assignment,
                              completed_at: (2 - index).days.ago)
    end
    create_assignment(classroom: @classroom, assignable: create_exercise(title: "Les volcans"), by: @teacher)
    create_exercise_session(student: @awa, exercise: create_exercise(title: "Les fractions"), status: "completed", score_percent: 70,
                            started_at: 3.days.ago, completed_at: 3.days.ago)
  end

  test "CL-13 : la fiche se lit au téléphone et à l'ordinateur ; code de récupération, puis retrait depuis la fiche" do
    sign_in_as @teacher
    visit classroom_student_path(@classroom.public_id, @awa.public_id)

    assert_selector "h1", text: "Awa Bamba", wait: SIGN_IN_WAIT
    assert_selector "#student_file_counts", text: /1 fait sur 2/
    assert_selector "#student_file_assignments li", text: %r{17/20.*En progrès.*2 sessions}m
    assert_selector "#student_file_self_practice li", text: "Les fractions"
    growth_shot("rapports-de-classe-fiche-1280")

    with_mobile_viewport do
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                      page.evaluate_script("document.documentElement.clientWidth")
      growth_shot("rapports-de-classe-fiche-390", desktop: false)
    end

    click_on I18n.t("#{SCOPE}.manage.issue_code")
    assert_selector "turbo-frame#modal dialog#pin-recovery-code-modal[open]"
    click_on I18n.t("identity.pin_recovery_codes.code.close")

    click_on I18n.t("#{SCOPE}.manage.remove")
    within("dialog#remove-student-#{@awa.public_id}") { click_on I18n.t("#{SCOPE}.manage.remove_confirm") }

    assert_current_path classroom_path(@classroom.public_id)
    assert_toast I18n.t("classroom.classrooms.roster.removed", name: "Awa Bamba")
    assert_no_selector "#student_#{@awa.public_id}"
  end
end
