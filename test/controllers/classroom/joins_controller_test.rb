require "test_helper"

# ID-01, ID-02, ID-07, CL-06, CL-07, CL-08, TR-cadre-1, Sécurité n° 5 (ADR-0040, ADR-0041, ADR-0050, UDR-0009):
# a visitor opens /c/<code>, sees only the classroom, its level and its school, signs up as a student and lands home,
# signed in; a signed-in student whose classroom is archived joins the new one; any other role is refused.
# IL-08, IL-09, IL-10 (ADR-0085 §4.1, UDR-0081 §3.4): /c/<token> — 12 hexadecimal characters — opens the student sign-up
# with the classroom already chosen; an invalid token opens the standard page with the alert. A 5-character code keeps
# the former path above, unchanged, until Lot F.
class Classroom::JoinsControllerTest < ActionDispatch::IntegrationTest
  ERRORS = "activemodel.errors.models.dtos/classroom/join_with_code_input.attributes".freeze

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school: @school, level: create_level(name: "6ème"), name: "6ème 1", join_code: "kfm37")
  end

  test "ID-02, CL-08: the preview names the classroom, its level and its school, and the form asks for the person and a PIN" do
    teacher = create_teacher(classrooms: [ @classroom ], last_name: "Yao", first_name: "Konan")
    create_student(classroom: @classroom, last_name: "Bamba", first_name: "Issa")

    get join_classroom_path("KFM37")

    assert_response :success
    assert_select "#classroom-preview", text: /6ème 1 — Lycée Classique d'Abidjan/
    assert_select "#classroom-preview", text: /6ème/
    assert_select "form#join-form[action='#{join_classroom_path('kfm37')}'][method=post]"
    %w[last_name first_name contact].each { assert_select "input[name='join[#{it}]']" }
    assert_select "input[type=radio][name='join[gender]']", count: 2
    assert_select "input[type=password][name='join[pin]'][inputmode=numeric][maxlength='4'][autocomplete=new-password]"
    assert_select "input[type=password][name='join[pin_confirmation]'][inputmode=numeric][maxlength='4']"
    assert_select "input[name*=role]", count: 0
    assert_select "a[href='#{new_session_path}']"
    [ "Yao", "Konan", "Bamba", "Issa", teacher.public_id, @classroom.public_id, "/ 80", "1 élève" ].each do |secret|
      assert_not_includes response.body, secret
    end
  end

  test "ID-02: an unknown code answers 404 with « Code de classe invalide. » and a link to type another one" do
    get join_classroom_path("zzz99")

    assert_response :not_found
    assert_select "h1", text: I18n.t("classroom.joins.new.invalid_code.title")
    assert_select "a[href='#{new_join_code_path}']", text: I18n.t("classroom.joins.new.invalid_code.other_code")
    assert_select "form#join-form", count: 0
  end

  test "CL-06: an old code, replaced since, answers 404, on the page and on the form" do
    @classroom.update!(join_code: "abc23")

    get join_classroom_path("kfm37")

    assert_response :not_found

    post join_classroom_path("kfm37"), params: { join: join_params }

    assert_response :not_found
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "ID-01, CL-06: a complete sign-up creates the student, their primary membership and their session" do
    freeze_time do
      post join_classroom_path("KFM37"), params: { join: join_params }

      assert_redirected_to student_home_path
      assert_response :see_other
      assert_equal I18n.t("classroom.joins.create.welcome"), flash[:notice]
      student = Orm::User.find_by!(contact: "0701020304")
      assert_equal [ "student", nil, "Kouassi", "Aya Marie", "female" ],
                   [ student.role, student.team_role, student.last_name, student.first_name, student.gender ]
      assert_equal [ [ @classroom.id, true, Time.current, nil ] ],
                   Orm::ClassroomStudent.where(student:).pluck(:classroom_id, :primary, :joined_at, :left_at)
      assert Orm::User.authenticate_by(contact: "0701020304", pin: "4821")
      assert_equal 1, Orm::Session.where(user: student).count
      assert cookies[:session_token].present?
    end
  end

  test "TR-cadre-1: a role added by hand is ignored, the account is a student and no team account exists" do
    post join_classroom_path("kfm37"), params: { join: join_params(role: "team", team_role: "admin"), role: "school_admin" }

    assert_redirected_to student_home_path
    assert_equal [ "student", nil ], Orm::User.where(contact: "0701020304").pick(:role, :team_role)
    assert_not Orm::User.exists?(role: %w[team school_admin])
  end

  test "ID-01, Sécurité n° 5: a blank PIN is refused in 422, never replaced by the number, and no account is created" do
    post join_classroom_path("kfm37"), params: { join: join_params(pin: "", pin_confirmation: "") }

    assert_refused :pin, I18n.t("#{ERRORS}.pin.blank")
  end

  test "ID-01: a different confirmation is refused in 422, the entries are kept, the PINs are not" do
    post join_classroom_path("kfm37"), params: { join: join_params(pin_confirmation: "1357") }

    assert_refused :pin_confirmation, I18n.t("#{ERRORS}.pin_confirmation.confirmation")
    assert_select "#classroom-preview", text: /6ème 1/
    assert_select "input[name='join[last_name]'][value='Kouassi']"
    assert_select "input[name='join[contact]'][value='07 01 02 03 04']"
    assert_select "input[name='join[gender]'][value=female][checked]"
    assert_select "input[name='join[pin]'][value]", count: 0
  end

  test "a number already used is refused in 422 with its message" do
    create_user(role: "teacher", contact: "0701020304")

    post join_classroom_path("kfm37"), params: { join: join_params }

    assert_response :unprocessable_entity
    assert_select "#join_contact_error", text: I18n.t("#{ERRORS}.contact.taken")
    assert_equal 0, Orm::ClassroomStudent.count
  end

  test "CL-06: an archived classroom is refused with its reason, and no account is created" do
    @classroom.update!(status: "archived", archived_at: Time.current)

    post join_classroom_path("kfm37"), params: { join: join_params }

    assert_response :forbidden
    assert_select "[role=alert]", text: I18n.t("#{ERRORS}.base.classroom_archived")
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "CL-06: a full classroom is refused with its reason, and no account is created" do
    @classroom.update!(max_students: 1)
    create_student(classroom: @classroom)

    post join_classroom_path("kfm37"), params: { join: join_params }

    assert_response :forbidden
    assert_select "[role=alert]", text: I18n.t("#{ERRORS}.base.classroom_full")
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "ID-07, CL-08: the eleventh page opened in a minute from the same address receives 429, without the preview" do
    10.times { |index| get join_classroom_path(index.even? ? "kfm37" : "zzz99") }

    get join_classroom_path("kfm37")

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /#{Regexp.escape(I18n.t('errors.codes.rate_limited'))}/
    assert_not_includes response.body, "6ème 1"
  end

  test "the limit also counts the sign-ups" do
    10.times { post join_classroom_path("kfm37"), params: { join: join_params(pin_confirmation: "1357") } }

    post join_classroom_path("kfm37"), params: { join: join_params }

    assert_response :too_many_requests
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "a signed-in teacher receives 403, on the page and on the form" do
    sign_in_as create_teacher

    get join_classroom_path("kfm37")

    assert_response :forbidden
    assert_not_includes response.body, "6ème 1"

    post join_classroom_path("kfm37"), params: { join: join_params }

    assert_response :forbidden
    assert_not Orm::User.exists?(contact: "0701020304")
  end

  test "a team member receives 403, even before their second factor" do
    sign_in_as create_team_member(second_factor: false)

    get join_classroom_path("kfm37")

    assert_response :forbidden

    sign_out
    sign_in_as create_team_member

    post join_classroom_path("kfm37"), params: { join: join_params }

    assert_response :forbidden
    assert_equal 0, Orm::ClassroomStudent.count
  end

  test "CL-06: a signed-in student sees a single « Join this classroom » button, never the sign-up form" do
    sign_in_as create_student

    get join_classroom_path("kfm37")

    assert_response :success
    assert_select "#classroom-preview", text: /6ème 1/
    assert_select "form#join-form[action='#{join_classroom_path('kfm37')}'] button", text: I18n.t("classroom.joins.new.join_as_student")
    assert_select "input[name='join[pin]']", count: 0
  end

  test "CL-06, IL-18: a student whose primary classroom is active is sent home from the page, refused in 403 on the form" do
    current = create_classroom(school: @school, name: "5ème 2")
    student = create_student(classroom: current)
    sign_in_as student

    get join_classroom_path("kfm37")

    assert_redirected_to student_home_path

    post join_classroom_path("kfm37")

    assert_response :forbidden
    assert_select "[role=alert]", text: I18n.t("#{ERRORS}.base.already_enrolled")
    assert_equal "Tu es déjà inscrit dans une classe.", I18n.t("#{ERRORS}.base.already_enrolled")
    assert_equal [ [ current.id, nil ] ], Orm::ClassroomStudent.where(student:).pluck(:classroom_id, :left_at)
  end

  test "CL-06: a student whose primary classroom is archived leaves it and joins the new one, without a new account" do
    archived = create_classroom(school: @school, name: "6ème 3", status: "archived")
    student = create_student(classroom: archived)
    sign_in_as student

    assert_no_difference -> { Orm::User.count } do
      post join_classroom_path("kfm37")
    end

    assert_redirected_to student_home_path
    assert_equal I18n.t("classroom.joins.create.welcome"), flash[:notice]
    memberships = Orm::ClassroomStudent.where(student:).order(:joined_at).pluck(:classroom_id, :primary, :left_at)
    assert_equal [ archived.id, true ], memberships.first.first(2)
    assert_not_nil memberships.first.last
    assert_equal [ @classroom.id, true, nil ], memberships.last
  end

  test "a signed-in student refused by the policy sees the reason" do
    @classroom.update!(status: "archived", archived_at: Time.current)
    sign_in_as create_student

    post join_classroom_path("kfm37")

    assert_response :forbidden
    assert_select "[role=alert]", text: I18n.t("#{ERRORS}.base.classroom_archived")
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
      assert_select "input[name='student_registration[full_name]']"
      assert_select "button#student-registration-submit:not([disabled])"
    end
    assert_select "select[name='student_registration[drena_public_id]'], turbo-frame#picker_schools, #classroom-link-invalid", 0
    assert_select "[name*=code]", 0
    assert_not_includes join_classroom_path(token), "kfm37"
    [ "Yao", "Konan", "Bamba", "Issa", teacher.public_id, @classroom.public_id, "kfm37", "KFM37", "/ 80" ].each do |secret|
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

  def assert_refused(attribute, message)
    assert_response :unprocessable_entity
    assert_select "#join_#{attribute}_error", text: message
    assert_not Orm::User.exists?(contact: "0701020304")
  end
end
