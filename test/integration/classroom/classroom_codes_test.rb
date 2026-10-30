require "test_helper"

# CA-B2, CA-B3, CA-B4 (ADR code-de-classe-a-six-caracteres §4.4, §4.5): GET /classroom-codes/:code answers with a Turbo Frame
# that names the classroom, its level and its school and nothing more; an unknown code and an archived classroom answer the
# same; the counter of /c/<token> (scope classroom/joins, 10 a minute and per address) is shared with this check.
class Classroom::ClassroomCodesTest < ActionDispatch::IntegrationTest
  FRAME = { "Turbo-Frame" => "classroom_code_preview" }.freeze
  PAGE = "classroom.classroom_codes.show".freeze

  setup do
    @school = create_school(name: "Collège Moderne 1 de Tiassalé")
    @classroom = create_classroom(school: @school, level: create_level(name: "3ème"), name: "3e B")
    @code = @classroom.reload.join_code
  end

  def check(code = @code, headers: FRAME) = get(classroom_code_path(code), headers:)

  test "CA-B2: a visitor who types « k7m 4q2 » sees the classroom, its level and its school, in a frame, without signing in" do
    get "/classroom-codes/#{@code[0, 3].upcase}%20#{@code[3, 3]}", headers: FRAME

    assert_response :success
    assert_select "turbo-frame#classroom_code_preview" do
      assert_select "#classroom-code-found[role=status]", text: /3e B/
      assert_select "#classroom-code-found", text: /Collège Moderne 1 de Tiassalé/
      assert_select "#classroom-code-found", text: /3ème/
      assert_select "#classroom-code-full", 0
    end
  end

  test "CA-B2: the school is shown by its acronym when it has one" do
    @school.update!(sigle: "CM1 Tiassalé")

    check

    assert_select "#classroom-code-found", text: /CM1 Tiassalé/
    assert_no_match(/Collège Moderne 1 de Tiassalé/, response.body)
  end

  test "CA-B2: the answer holds no student, no teacher and no internal identifier" do
    teacher = create_teacher(classrooms: [ @classroom ], last_name: "Yaoteacher")
    student = create_student(classroom: @classroom, last_name: "Bambastudent")

    check

    [ "Yaoteacher", "Bambastudent", @classroom.public_id, @classroom.link_token, @school.public_id, teacher.public_id,
      student.public_id ].each { assert_no_match(/#{Regexp.escape(it)}/, response.body) }
    assert_no_match(/#{@classroom.id}\b.*data-/, response.body)
  end

  test "a full classroom is said to be full" do
    @classroom.update!(max_students: 1)
    create_student(classroom: @classroom)

    check

    assert_select "#classroom-code-found"
    assert_select "#classroom-code-full[role=alert]", text: I18n.t("#{PAGE}.full")
  end

  test "CA-B3: an unknown code, a malformed one and an archived classroom answer exactly the same" do
    check "zzzzzz"
    unknown = [ response.status, response.body ]
    assert_select "#classroom-code-unknown", text: /#{Regexp.escape(I18n.t("#{PAGE}.unknown"))}/
    assert_select "#classroom-code-found", 0

    check "abc"
    assert_equal unknown, [ response.status, response.body ]

    @classroom.update!(status: "archived", archived_at: Time.current)
    check

    assert_equal unknown, [ response.status, response.body ]
  end

  test "CA-B3: the same holds without the frame header (a full page for the unknown code and for the archived one)" do
    check "zzzzzz", headers: {}
    unknown_status = response.status
    unknown_shape = css_select("#classroom-code-unknown").map(&:to_s)

    @classroom.update!(status: "archived", archived_at: Time.current)
    check @code, headers: {}

    assert_equal unknown_status, response.status
    assert_equal unknown_shape, css_select("#classroom-code-unknown").map(&:to_s)
  end

  test "CA-B4: the 11th request of the minute from one address gets 429, « Trop de tentatives » (UDR-0007: no « essai »), and nothing of the classroom" do
    10.times { check }
    assert_response :success

    check

    assert_response :too_many_requests
    assert_select "turbo-frame#classroom_code_preview #classroom-code-rate-limited[role=alert]", text: /#{Regexp.escape(I18n.t("#{PAGE}.rate_limited"))}/
    assert_select "#classroom-code-found", 0
    assert_no_match(/3e B/, response.body)
  end

  # ADR-0085 §4.7: the code check keeps its 10 a minute; the link of a class has its own counter and stays open.
  test "CA-B4: ten checks of a code, then the 11th is refused, while the link of a class still opens" do
    token = @classroom.link_token
    10.times { check "zzzzzz" }

    check
    assert_response :too_many_requests

    get join_classroom_path(token)
    assert_response :success
  end

  test "CA-B4: another address has its own counter" do
    10.times { check }
    check
    assert_response :too_many_requests

    get classroom_code_path(@code), headers: FRAME, env: { "REMOTE_ADDR" => "203.0.113.9" }

    assert_response :success
  end

  test "CA-B6: after « Changer le lien et le code », the old code is unknown and the new one is found" do
    Repositories::Classroom::ClassroomRepository.new.regenerate_link_and_code(id: @classroom.id)

    check
    assert_select "#classroom-code-unknown"

    check @classroom.reload.join_code
    assert_select "#classroom-code-found", text: /3e B/
  end

  test "CA-B6: the teacher who changes the link changes the code with it; the old code is unknown, the change is journaled without secret" do
    teacher = create_teacher(classrooms: [ @classroom ])
    old_token = @classroom.link_token
    sign_in_as teacher

    patch classroom_link_path(@classroom.public_id), as: :turbo_stream
    assert_response :success
    reset!

    @classroom.reload
    assert_not_equal @code, @classroom.join_code
    assert_not_equal old_token, @classroom.link_token
    check
    assert_select "#classroom-code-unknown"
    check @classroom.join_code
    assert_select "#classroom-code-found", text: /3e B/
    event = Orm::AuditEvent.find_by!(action: "school.changed", actor_id: teacher.id, subject_id: @school.id)
    assert_equal "classroom_link_and_code_changed", event.metadata["change"]
    assert_no_match(/#{@code}|#{@classroom.join_code}|#{old_token}|#{@classroom.link_token}/, event.metadata.to_s)
  end

  test "the route takes anything as a code and reads the database for nothing malformed" do
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?("join_code") }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      check "%27%20OR%201=1--"
      check "a" * 300
    end

    assert_response :success
    assert_select "#classroom-code-unknown"
    assert_empty queries
  end
end
