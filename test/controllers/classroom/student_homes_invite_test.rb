require "test_helper"

# Lot B (partage-classe-k-factor), UDR partage-de-classe §3.3: the invitations of the student home (the classmates banner became a tile, chantier entree-et-accueil-eleve-allegees Lot D).
class Classroom::StudentHomesInviteTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "3e B", school: create_school(name: "Collège Moderne"))
    @student = create_student(classroom: @classroom)
    sign_in_as(@student)
  end

  test "the classmates tile is in the grid and opens WhatsApp in a new tab; no section, no banner any more" do
    get student_home_path

    assert_select "#student_invite_classmates", count: 0
    assert_select "li#student_invite_cell" do
      assert_select "form[action=?][target=_blank][data-turbo=false]", class_invite_path
      assert_select "button[data-action*=dismissible], p", count: 0
    end
  end

  test "the teacher invitation shows while the classroom has no teacher" do
    get student_home_path

    assert_select "section#student_invite_banner"
  end

  test "the teacher invitation disappears when the classroom has a teacher" do
    create_teacher(classrooms: [ @classroom ])
    get student_home_path

    assert_select "section#student_invite_banner", count: 0
    assert_select "li#student_invite_cell"
  end

  test "a student without a classroom sees neither" do
    Orm::ClassroomStudent.where(student_id: @student.id).update_all(left_at: Time.current)
    get student_home_path

    assert_select "#student_invite_cell", count: 0
  end
end
