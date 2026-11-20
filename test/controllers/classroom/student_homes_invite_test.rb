require "test_helper"

# Lot B (partage-classe-k-factor), UDR partage-de-classe §3.3: the banners of the student home.
class Classroom::StudentHomesInviteTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "3e B", school: create_school(name: "Collège Moderne"))
    @student = create_student(classroom: @classroom)
    sign_in_as(@student)
  end

  test "the classmates banner is there, without a cross, and opens WhatsApp in a new tab" do
    get student_home_path

    assert_select "section#student_invite_classmates_title, section[aria-labelledby=student_invite_classmates_title]" do
      assert_select "h2#student_invite_classmates_title", text: "Invite tes camarades"
      assert_select "form[action=?][target=_blank][data-turbo=false]", class_invite_path
      assert_select "button[data-action*=dismissible]", count: 0
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
    assert_select "h2#student_invite_classmates_title"
  end

  test "a student without a classroom sees neither" do
    Orm::ClassroomStudent.where(student_id: @student.id).update_all(left_at: Time.current)
    get student_home_path

    assert_select "#student_invite_classmates_title", count: 0
  end
end
