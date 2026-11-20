require "test_helper"

# Lot B (partage-classe-k-factor), UDR partage-de-classe §3.3: « Invite tes camarades » answers 303 to WhatsApp.
class Classroom::ClassInvitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(name: "3e B", school: create_school(name: "Collège Moderne"))
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouassi")
  end

  def location_text = CGI.unescape(response.location.split("text=").last)

  test "the student goes to WhatsApp with the classroom link and his own code, twice the same" do
    sign_in_as(@student)

    post class_invite_path
    first = location_text

    assert_response :see_other
    assert_match %r{\Ahttps://wa\.me/\?text=}, response.location
    assert_includes first, "Rejoins la classe 3e B de Collège Moderne sur Lnclass : "
    assert_match %r{/c/#{@classroom.link_token}\?i=[a-hjkmnp-z2-9]{8}\z}, first
    refute_includes first, "Aya"
    refute_includes first, "Kouassi"

    post class_invite_path

    assert_equal first, location_text
    assert_equal 1, Orm::StudentInviteCode.where(student_id: @student.id).count
  end

  test "without an active classroom: the home, and no code" do
    Orm::ClassroomStudent.where(student_id: @student.id).update_all(left_at: Time.current)
    sign_in_as(@student)

    post class_invite_path

    assert_redirected_to student_home_path
    assert_response :see_other
    assert_equal 0, Orm::StudentInviteCode.count
  end

  test "a teacher is refused" do
    sign_in_as(create_teacher)

    post class_invite_path

    assert_response :forbidden
    assert_equal 0, Orm::StudentInviteCode.count
  end

  test "after three collisions: 503, nothing created, and the log names only the student" do
    other = create_student
    taken = Repositories::Classroom::InviteCodeRepository.new.code_for(student_id: other.id).value
    sign_in_as(@student)
    logged = []

    stub_method(Entities::Classroom::InviteCode, :generate, -> { taken }) do
      stub_method(Rails.logger, :error, ->(message = nil, &block) { logged << (message || block&.call) }) do
        post class_invite_path
      end
    end

    assert_response :service_unavailable
    assert_equal 0, Orm::StudentInviteCode.where(student_id: @student.id).count
    assert_equal [ "InviteCodeRepository: code unavailable for student_id=#{@student.id}" ], logged.grep(/InviteCodeRepository/)
    assert_not_includes logged.join, taken
  end
end
