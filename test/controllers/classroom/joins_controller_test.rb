require "test_helper"

# IL-02, IL-08, IL-09, IL-10, IL-16, IL-18 (ADR-0085 §4.1, §4.3, UDR-0081 §3.4): /c/<token> — 12 hexadecimal characters —
# opens the student sign-up with the classroom already chosen, or the « Join this classroom » button of a student without
# a classroom; any other parameter, an old classroom code (/c/kfm37) included, opens the standard page with the alert.
# There is no classroom code any more (Lot F): /join leads to /student-signup. Any role but the student is refused.
class Classroom::JoinsControllerTest < ActionDispatch::IntegrationTest
  ERRORS = "activemodel.errors.models.dtos/classroom/student_registration_input.attributes".freeze

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school: @school, level: create_level(name: "6ème"), name: "6ème 1")
  end

  test "IL-02: /join, the former entry by code, leads to /student-signup; nothing is posted there any more" do
    get "/join"

    assert_redirected_to "/student-signup"
    assert_response :moved_permanently
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/join", method: :post) }
  end

  test "IL-09: an old classroom code link opens the standard page with the alert, and is never looked up" do
    [ "kfm37", "KFM37", "zzz99" ].each do |old|
      get join_classroom_path(old)

      assert_redirected_to new_student_registration_path
      follow_redirect!
      assert_select "#classroom-link-invalid[role=alert]", text: I18n.t("classroom.student_registrations.form.link_invalid")
      assert_select "#classroom-preview", 0
    end

    post join_classroom_path("kfm37"), params: { join: join_params }

    assert_redirected_to new_student_registration_path
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "a team member receives 403 on the link page, even before their second factor" do
    sign_in_as create_team_member(second_factor: false)

    get join_classroom_path(link_token)

    assert_response :forbidden
    assert_not_includes response.body, "6ème 1"

    sign_out
    sign_in_as create_team_member
    post join_classroom_path(link_token)

    assert_response :forbidden
    assert_equal 0, Orm::ClassroomStudent.count
  end


  test "IL-08: a visitor opening the link sees the sign-up page, the classroom, its school and level already chosen" do
    teacher = create_teacher(classrooms: [ @classroom ], last_name: "Yao", first_name: "Konan")
    create_student(classroom: @classroom, last_name: "Bamba", first_name: "Issa")
    token = link_token

    get join_classroom_path(token.upcase)

    assert_response :success
    assert_select "h2", text: I18n.t("classroom.student_registrations.new.title")
    assert_select "form#student-registration-form[action='#{student_registrations_path}'][method=post]" do
      assert_select "#classroom-preview", text: /6ème 1 — Lycée Classique d'Abidjan/
      assert_select "#classroom-preview", text: /Niveau : 6ème/
      assert_select "input[type=hidden][name='student_registration[link_token]'][value='#{token}']"
      assert_select "a#other-classroom[href='#{new_student_registration_path}']",
                    text: I18n.t("classroom.student_registrations.form.other_classroom")
      assert_select "input[name='student_registration[last_name]']"
      assert_select "button#student-registration-submit:not([disabled])"
    end
    assert_select "select[name='student_registration[drena_public_id]'], turbo-frame#picker_schools, #classroom-link-invalid", 0
    assert_select "[name*=code]", 0
    [ "Yao", "Konan", "Bamba", "Issa", teacher.public_id, @classroom.public_id, "/ 80" ].each do |secret|
      assert_not_includes response.body, secret
    end
  end

  test "IL-10: « Ce n'est pas ta classe ? » opens the standard page without the alert" do
    get join_classroom_path(link_token)
    get css_select("a#other-classroom").first["href"]

    assert_response :success
    assert_select "select[name='student_registration[drena_public_id]']"
    assert_select "#classroom-link-invalid, #classroom-preview", 0
  end

  test "IL-09: an unknown or changed token, an archived classroom or a closed school opens the standard page with the alert" do
    token = link_token
    archived = create_classroom(school: @school, name: "6ème 2", status: "archived")
    closed = create_classroom(school: create_school(status: "inactive"), name: "6ème 1")

    [ "cccccccccccc", archived.reload.link_token, closed.reload.link_token ].each do |invalid|
      get join_classroom_path(invalid)

      assert_redirected_to new_student_registration_path
      follow_redirect!
      assert_select "#classroom-link-invalid[role=alert]", text: I18n.t("classroom.student_registrations.form.link_invalid")
      assert_select "#classroom-preview", 0
      assert_no_match(/6ème 2/, response.body)
    end

    @classroom.update!(link_token: "ffffffffffff")
    get join_classroom_path(token)

    assert_redirected_to new_student_registration_path
  end

  test "IL-05: the link of a full classroom shows the classroom and « Cette classe est complète. », without a form" do
    @classroom.update!(max_students: 1)
    create_student(classroom: @classroom)

    get join_classroom_path(link_token)

    assert_response :success
    assert_select "#classroom-preview", text: /6ème 1/
    assert_select "#classroom-full[role=alert]", text: I18n.t("classroom.joins.new.classroom_full")
    assert_equal "Cette classe est complète.", I18n.t("classroom.joins.new.classroom_full")
    assert_select "form, button[type=submit]", 0
  end

  test "a visitor posting to the link is sent back to the link page" do
    post join_classroom_path(link_token), params: { join: join_params }

    assert_redirected_to join_classroom_path(link_token)
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "a signed-in teacher receives 403 on the link page" do
    sign_in_as create_teacher

    get join_classroom_path(link_token)

    assert_response :forbidden
    assert_not_includes response.body, "6ème 1"
  end

  test "UDR-0081 §3.4: a student without a classroom sees the single « Join this classroom » button, and joins by it" do
    archived = create_classroom(school: @school, name: "6ème 3", status: "archived")
    student = create_student(classroom: archived)
    sign_in_as student
    token = link_token

    get join_classroom_path(token)

    assert_response :success
    assert_select "#classroom-preview", text: /6ème 1/
    assert_select "form#join-form[action='#{join_classroom_path(token)}'] button", text: I18n.t("classroom.joins.new.join_as_student")
    assert_select "input[name*=pin]", 0

    assert_no_difference -> { Orm::User.count } do
      post join_classroom_path(token)
    end

    assert_redirected_to student_home_path
    assert_equal I18n.t("classroom.joins.create.welcome"), flash[:notice]
    assert_equal [ @classroom.id, "link", nil ],
                 Orm::ClassroomStudent.where(student:, left_at: nil).pick(:classroom_id, :joined_via, :removed_at)
    assert_not_nil Orm::ClassroomStudent.find_by!(student:, classroom: archived).left_at
  end

  test "IL-18: a student in an active classroom opening a link is sent home; posting it is refused in 403 on the link page" do
    current = create_classroom(school: @school, name: "6ème 4")
    student = create_student(classroom: current)
    sign_in_as student

    get join_classroom_path(link_token)

    assert_redirected_to student_home_path

    post join_classroom_path(link_token)

    assert_response :forbidden
    assert_select "#classroom-preview", text: /6ème 1/
    assert_select "[role=alert]", text: I18n.t("#{ERRORS}.base.already_enrolled")
    assert_equal [ [ current.id, nil ] ], Orm::ClassroomStudent.where(student:).pluck(:classroom_id, :left_at)
  end

  test "IL-16: a student removed from the classroom joins it again by its link: the same membership reopens, « New » again" do
    student = create_student(classroom: @classroom, joined_via: "standard", joined_at: 30.days.ago)
    Orm::ClassroomStudent.where(student:).update_all(left_at: 2.days.ago, removed_at: 2.days.ago,
                                                     removed_by_id: create_teacher.id)
    sign_in_as student

    freeze_time do
      post join_classroom_path(link_token)

      assert_redirected_to student_home_path
      assert_equal [ [ @classroom.id, "link", Time.current, nil, nil, nil ] ],
                   Orm::ClassroomStudent.where(student:).pluck(:classroom_id, :joined_via, :joined_at, :left_at, :removed_at,
                                                                :removed_by_id)
    end
  end

  test "a student without a classroom is refused a full classroom by its link, with the reason, and enters nothing" do
    @classroom.update!(max_students: 1)
    create_student(classroom: @classroom)
    student = create_student
    sign_in_as student

    get join_classroom_path(link_token)

    assert_select "#classroom-full[role=alert]", text: I18n.t("classroom.joins.new.classroom_full")
    assert_select "form#join-form", 0

    post join_classroom_path(link_token)

    assert_response :forbidden
    assert_select "#classroom-full[role=alert]", text: I18n.t("classroom.joins.new.classroom_full")
    assert_not Orm::ClassroomStudent.exists?(student:)
  end

  test "UDR-0081 §3.4: an invalid link sends a student without a classroom to « Choose your classroom », with the alert" do
    sign_in_as create_student

    get join_classroom_path("cccccccccccc")

    assert_redirected_to new_student_classroom_choice_path
    assert flash[:link_invalid]

    post join_classroom_path("cccccccccccc")

    assert_redirected_to new_student_classroom_choice_path
  end

  test "ADR-0085 §4.2: the link page shares the limit of 10 openings a minute" do
    token = link_token
    10.times { |index| get join_classroom_path(index.even? ? token : "cccccccccccc") }

    get join_classroom_path(token)

    assert_response :too_many_requests
    assert_not_includes response.body, "6ème 1"
  end

  private

  def link_token = @classroom.reload.link_token

  def join_params(**overrides)
    { last_name: "Kouassi", first_name: "Aya Marie", gender: "female", contact: "07 01 02 03 04", pin: "4821",
      pin_confirmation: "4821", **overrides }
  end
end
