require "test_helper"

# ADR-0095, UDR-0102: a student whose classroom is active changes it themself. « Changer de classe » shows the cascade, the
# current school folded and the current classroom disabled; the confirmation reads the classroom again, says what changes,
# and only its POST writes. Refusals come back to « Changer de classe » with their reason; other roles are refused.
class Classroom::StudentClassroomChangesControllerTest < ActionDispatch::IntegrationTest
  ERRORS = "activemodel.errors.models.dtos/classroom/student_registration_input.attributes".freeze
  NEW = "classroom.student_classroom_changes.new".freeze
  CONFIRM = "classroom.student_classroom_changes.confirm".freeze

  setup do
    @drena = create_drena(name: "Abidjan 1")
    @cocody = create_school(drena: @drena, name: "Lycée Moderne de Cocody")
    @viateur = create_school(drena: @drena, name: "Collège Saint-Viateur")
    @level = create_level(name: "2nde")
    @a = create_classroom(school: @cocody, level: @level, name: "2nde A")
    @b = create_classroom(school: @cocody, level: @level, name: "2nde B")
    @c = create_classroom(school: @viateur, level: @level, name: "2nde C")
    @student = create_student(classroom: @a, first_name: "Awa", joined_at: 30.days.ago)
  end

  def cascade(classroom = @c, school: @viateur, **overrides)
    { drena_public_id: @drena.public_id, school_public_id: school.public_id, level_slug: @level.slug,
      classroom_public_id: classroom.public_id, **overrides }
  end

  def send_change(params = { student_classroom_change: cascade }) = post(student_classroom_change_path, params:)
  def open_memberships = Orm::ClassroomStudent.where(student: @student, left_at: nil).pluck(:classroom_id, :joined_via)
  def moves = Orm::AuditEvent.where(action: "classroom.student_moved")
  def refusal_message(key) = I18n.t("#{ERRORS}.base.#{key}")

  test "UDR-0102 §3.1: « Changer de classe », the current school folded, the current classroom marked, a GET to the confirmation" do
    sign_in_as @student

    get new_student_classroom_change_path

    assert_response :success
    assert_select "h1", text: "Changer de classe"
    assert_select "nav a[href='#{profile_path}']"
    assert_select "p", text: "Tu es en 2nde A · Lycée Moderne de Cocody."
    assert_select "form#student-classroom-change-form[action='#{confirm_student_classroom_change_path}'][method=get]" \
                  "[data-controller='classroom--class-picker']" \
                  "[data-classroom--class-picker-classrooms-url-value='" \
                  "#{school_picker_classrooms_path('__school__', '__level__', scope: :student_classroom_change, current: @a.public_id)}']" do
      assert_select "#class-picker-school-summary", text: /Lycée Moderne de Cocody/
      assert_select "turbo-frame#picker_levels input[type=radio][name='student_classroom_change[level_slug]']"
      assert_select "button#student-classroom-change-submit[type=submit]", text: I18n.t("#{NEW}.submit")
    end
    assert_equal "Continuer", I18n.t("#{NEW}.submit")
  end

  test "UDR-0102 §3.1: with the level chosen, the current classroom is disabled with « Ta classe » (repli sans JavaScript)" do
    sign_in_as @student

    get new_student_classroom_change_path, params: { student_classroom_change: cascade(@a, school: @cocody).except(:classroom_public_id) }

    assert_select "label", text: /2nde A/ do
      assert_select "input[type=radio][disabled][value='#{@a.public_id}']"
      assert_select "span", text: "Ta classe"
    end
    assert_select "input[type=radio][value='#{@b.public_id}']:not([disabled])"
  end

  test "UDR-0102 §3.2: the confirmation says « Tu quittes », « Tu rejoins », another school, what follows and what is left" do
    sign_in_as @student

    get confirm_student_classroom_change_path, params: { student_classroom_change: cascade }

    assert_response :success
    assert_select "h1", text: I18n.t("#{CONFIRM}.title")
    assert_select "dl" do
      assert_select "dt", text: "Tu quittes"
      assert_select "dt", text: "Tu rejoins"
      assert_select "dd", text: /2nde A/
      assert_select "dd", text: /2nde · Lycée Moderne de Cocody/
      assert_select "dd.bg-brand-soft", text: /2nde C/ do
        assert_select "span", text: "Autre établissement"
      end
    end
    assert_select "li", text: "Ton historique et tes résultats te suivent."
    assert_select "li", text: "Tu ne verras plus les devoirs ni les annonces de 2nde A."
    assert_select "form[action='#{student_classroom_change_path}'][method=post]" do
      cascade.each { |field, value| assert_select "input[type=hidden][name='student_classroom_change[#{field}]'][value='#{value}']" }
      assert_select "button[type=submit]", text: "Oui, changer de classe"
    end
    assert_select "a[href='#{new_student_classroom_change_path}']", text: I18n.t("#{CONFIRM}.cancel")
    assert_equal [ [ @a.id, "standard" ] ], open_memberships
    assert_empty moves
  end

  test "UDR-0102 §3.2: within the same school, no « Autre établissement »" do
    sign_in_as @student

    get confirm_student_classroom_change_path, params: { student_classroom_change: cascade(@b, school: @cocody) }

    assert_response :success
    assert_select "dd", text: /2nde B/
    assert_no_match(/Autre établissement/, response.body)
  end

  test "UDR-0102 §3.3: by a link, the classroom of the link, « par le lien de la classe », cancel goes home" do
    sign_in_as @student

    get confirm_student_classroom_change_path, params: { link_token: @c.link_token.upcase }

    assert_response :success
    assert_select "dd.bg-brand-soft", text: /2nde C/
    assert_select "dd", text: /par le lien de la classe/
    assert_select "form[action='#{student_classroom_change_path}'] input[type=hidden][name=link_token][value='#{@c.link_token}']"
    assert_select "form[action='#{student_classroom_change_path}'] input[name^=student_classroom_change]", 0
    assert_select "a[href='#{student_home_path}']", text: I18n.t("#{CONFIRM}.cancel")
  end

  test "the confirmation reads the classroom again: outside the cascade (422), the same one (422), full (403), dead link" do
    sign_in_as @student

    get confirm_student_classroom_change_path, params: { student_classroom_change: cascade(@c, school: @cocody) }

    assert_response :unprocessable_entity
    assert_select "#student_classroom_change_classroom_public_id_error", text: I18n.t("#{ERRORS}.classroom_public_id.unavailable")

    get confirm_student_classroom_change_path, params: { student_classroom_change: cascade(@a, school: @cocody) }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: refusal_message(:same_classroom)

    get confirm_student_classroom_change_path, params: { student_classroom_change: cascade.merge(classroom_public_id: "") }

    assert_response :unprocessable_entity
    assert_select "#student_classroom_change_classroom_public_id_error", text: I18n.t("#{ERRORS}.classroom_public_id.blank")

    @c.update!(max_students: 1)
    create_student(classroom: @c)
    get confirm_student_classroom_change_path, params: { student_classroom_change: cascade }

    assert_response :forbidden
    assert_select "[role=alert]", text: refusal_message(:classroom_full)

    get confirm_student_classroom_change_path, params: { link_token: "cccccccccccc" }

    assert_redirected_to new_student_classroom_change_path
    follow_redirect!

    assert_select "#classroom-link-invalid[role=alert]", text: I18n.t("#{NEW}.link_invalid")
  end

  test "ADR-0095: « Oui, changer de classe » leaves the old classroom without removal, enters the new one, traces it" do
    sign_in_as @student

    send_change

    assert_redirected_to student_home_path
    assert_response :see_other
    assert_equal "Bienvenue en 2nde C !", flash[:notice]
    assert_equal [ [ @c.id, "standard" ] ], open_memberships
    assert_equal [ [ @a.id, nil ] ], Orm::ClassroomStudent.where(student: @student).where.not(left_at: nil).pluck(:classroom_id, :removed_at)
    assert_equal [ [ @student.id, "User", @student.id, { "from_classroom_id" => @a.id, "to_classroom_id" => @c.id,
                                                         "to_school_id" => @viateur.id, "via" => "standard" } ] ],
                 moves.pluck(:actor_id, :subject_type, :subject_id, :metadata)
  end

  test "ADR-0095: by the link, way « link », even from a classroom the student was removed from" do
    Orm::ClassroomStudent.create!(classroom: @c, student: @student, primary: false, joined_at: 60.days.ago, left_at: 40.days.ago,
                                  removed_at: 40.days.ago, removed_by_id: create_teacher.id, joined_via: "standard")
    sign_in_as @student

    send_change(student_classroom_change: cascade)

    assert_response :forbidden
    assert_select "[role=alert]", text: refusal_message(:removed_from_classroom)
    assert_select "#class-picker-school-summary", text: /Collège Saint-Viateur/

    send_change(link_token: @c.link_token)

    assert_redirected_to student_home_path
    assert_equal [ [ @c.id, "link" ] ], open_memberships
  end

  test "refusals at sending come back to « Changer de classe »: same (422), full (403), dead link, outside the cascade (422)" do
    sign_in_as @student

    send_change(student_classroom_change: cascade(@a, school: @cocody))

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: refusal_message(:same_classroom)

    send_change(link_token: "cccccccccccc")

    assert_redirected_to new_student_classroom_change_path
    follow_redirect!

    assert_select "#classroom-link-invalid[role=alert]", text: I18n.t("#{NEW}.link_invalid")

    send_change(student_classroom_change: cascade(@c, school: @cocody))

    assert_response :unprocessable_entity
    assert_select "#student_classroom_change_classroom_public_id_error", text: I18n.t("#{ERRORS}.classroom_public_id.unavailable")

    @c.update!(max_students: 1)
    create_student(classroom: @c)
    send_change(link_token: @c.link_token)

    assert_response :forbidden
    assert_select "[role=alert]", text: refusal_message(:classroom_full)
    assert_select "#class-picker-school-summary", text: /Collège Saint-Viateur/
    assert_equal [ [ @a.id, "standard" ] ], open_memberships
    assert_empty moves
  end

  test "a student without an active classroom is sent to « Choisis ta classe », on every action" do
    @a.update!(status: "archived", archived_at: Time.current)
    sign_in_as @student

    get new_student_classroom_change_path

    assert_redirected_to new_student_classroom_choice_path

    get confirm_student_classroom_change_path, params: { student_classroom_change: cascade }

    assert_redirected_to new_student_classroom_choice_path

    send_change

    # Classe archivée entre la confirmation et l'envoi : « Choisis ta classe » dit pourquoi.
    assert_redirected_to new_student_classroom_choice_path
    assert_equal refusal_message(:no_active_classroom), flash[:alert]
    assert_equal [ [ @a.id, "standard" ] ], open_memberships
    assert_empty moves
  end

  test "the sixth sending of a minute receives 429, nothing more is written" do
    sign_in_as @student

    5.times { send_change(student_classroom_change: cascade(@a, school: @cocody)) }
    send_change

    assert_response :too_many_requests
    assert_select "[role=alert]", text: I18n.t("errors.codes.rate_limited")
    assert_equal [ [ @a.id, "standard" ] ], open_memberships
  end

  test "a visitor is sent to sign in on every action; a teacher, a direction or the team is refused" do
    get new_student_classroom_change_path

    assert_redirected_to new_session_path

    get confirm_student_classroom_change_path, params: { link_token: @c.link_token }

    assert_redirected_to new_session_path

    send_change

    assert_redirected_to new_session_path

    [ create_teacher, create_user(role: "school_admin"), create_team_member ].each do |user|
      sign_in_as user
      get new_student_classroom_change_path

      assert_response :forbidden

      send_change

      assert_response :forbidden
      sign_out
    end
    assert_empty moves
  end

  test "ADR-0095 §4.4: the 61st link confirmation of a minute receives 429, without anything of the classroom" do
    sign_in_as @student

    60.times { get confirm_student_classroom_change_path, params: { link_token: "cccccccccccc" } }

    assert_redirected_to new_student_classroom_change_path

    get confirm_student_classroom_change_path, params: { link_token: @c.link_token }

    assert_response :too_many_requests
    assert_select "[role=alert]", text: I18n.t("errors.codes.rate_limited")
    assert_select "h1", text: "Changer de classe"
    assert_no_match(/#{@c.public_id}|#{@c.link_token}|2nde C/, response.body)
  end

  test "ADR-0085 §4.1: the link confirmation shares the link counter (60 a minute) of /c/<jeton>" do
    sign_in_as @student

    60.times { get join_classroom_path("cccccccccccc") }
    get confirm_student_classroom_change_path, params: { link_token: @c.link_token }

    assert_response :too_many_requests
  end

  test "ADR-0050: the move is traced with the address of the request" do
    sign_in_as @student

    post student_classroom_change_path, params: { student_classroom_change: cascade }, env: { "REMOTE_ADDR" => "203.0.113.9" }

    assert_equal [ "203.0.113.9" ], moves.pluck(:ip_address)
  end

  test "ADR-0088: the link of an archived classroom says so at the confirmation, as at the sending (403)" do
    @c.update!(status: "archived", archived_at: Time.current)
    sign_in_as @student

    get confirm_student_classroom_change_path, params: { link_token: @c.link_token }

    assert_response :forbidden
    assert_select "[role=alert]", text: refusal_message(:classroom_archived)
    assert_select "#classroom-link-invalid", 0
  end

  test "a classroom archived between the confirmation and the sending: by the link 403 with the reason, by the cascade 422" do
    sign_in_as @student
    get confirm_student_classroom_change_path, params: { link_token: @c.link_token }
    @c.update!(status: "archived", archived_at: Time.current)

    send_change(link_token: @c.link_token)

    assert_response :forbidden
    assert_select "[role=alert]", text: refusal_message(:classroom_archived)

    send_change

    assert_response :unprocessable_entity
    assert_select "#student_classroom_change_classroom_public_id_error", text: I18n.t("#{ERRORS}.classroom_public_id.unavailable")
    assert_equal [ [ @a.id, "standard" ] ], open_memberships
    assert_empty moves
  end

  test "the same sending twice (double tap): the second is same_classroom, one open membership, one trace" do
    sign_in_as @student

    send_change
    send_change

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: refusal_message(:same_classroom)
    assert_equal [ [ @c.id, "standard" ] ], open_memberships
    assert_equal 1, moves.count
  end

  test "own classroom full: same_classroom, never classroom_full, at the confirmation as at the sending" do
    @a.update!(max_students: 1)
    sign_in_as @student

    get confirm_student_classroom_change_path, params: { link_token: @a.link_token }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: refusal_message(:same_classroom)

    send_change(link_token: @a.link_token)

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: refusal_message(:same_classroom)
  end

  test "ADR-0085 §4.3: the link lifts the removal on the same row, removal cleared" do
    Orm::ClassroomStudent.create!(classroom: @c, student: @student, primary: true, joined_at: 60.days.ago, left_at: 40.days.ago,
                                  removed_at: 40.days.ago, removed_by_id: create_teacher.id, joined_via: "standard")
    sign_in_as @student

    send_change(link_token: @c.link_token)

    assert_equal [ [ "link", nil, nil, nil ] ],
                 Orm::ClassroomStudent.where(student: @student, classroom: @c).pluck(:joined_via, :left_at, :removed_at, :removed_by_id)
  end

  test "back to 2nde A by the cascade after A → C: the same row reopened, two moves" do
    sign_in_as @student

    send_change
    send_change(student_classroom_change: cascade(@a, school: @cocody))

    assert_redirected_to student_home_path
    assert_equal [ nil ], Orm::ClassroomStudent.where(student: @student, classroom: @a).pluck(:left_at)
    assert_equal [ [ @a.id, "standard" ] ], open_memberships
    assert_equal 2, moves.count
  end

  # add_primary of the real repository answers `behaviour` (a lambda) for the duration of the block.
  def with_add_primary(behaviour)
    repository = Repositories::Classroom::MembershipRepository
    repository.alias_method :original_add_primary, :add_primary
    repository.define_method(:add_primary, behaviour)
    yield
  ensure
    repository.alias_method :add_primary, :original_add_primary
    repository.remove_method :original_add_primary
  end

  test "a race between two classrooms (:conflict): a neutral « Réessaie », the old membership kept, a warning without contact" do
    sign_in_as @student
    logs = StringIO.new
    Rails.logger.broadcast_to(log = ActiveSupport::Logger.new(logs))

    with_add_primary(->(**) { Shared::Result.failure(:conflict, errors: { base: [ :already_member ] }) }) do
      send_change
      send_change(link_token: @c.link_token)
    end

    assert_response :conflict
    assert_select "[role=alert]", text: refusal_message(:change_conflict)
    assert_equal [ [ @a.id, "standard" ] ], open_memberships
    assert_empty moves
    assert_equal 2, logs.string.scan(/classroom\.change_conflict user_id=#{@student.id} to_classroom=#{@c.public_id}$/).size
    assert_no_match(/#{@c.link_token}/, logs.string)
    assert_no_match(/#{@student.contact}/, logs.string)
  ensure
    Rails.logger.stop_broadcasting_to(log) if log
  end

  test "atomicity with the real repositories: a failing new membership leaves the old one open, nothing traced" do
    sign_in_as @student

    assert_raises(RuntimeError) { with_add_primary(->(**) { raise "panne" }) { send_change } }

    assert_equal [ [ @a.id, "standard" ] ], open_memberships
    assert_empty moves
  end

  test "ADR-0095 §4.3: the results follow the student; the old follow-up loses them, the new one does not gain them" do
    teacher_a = create_teacher(school: @cocody, classrooms: [ @a ], first_name: "Ibrahim", last_name: "Traoré")
    teacher_c = create_teacher(school: @viateur, classrooms: [ @c ], first_name: "Moussa", last_name: "Diallo")
    exercise = create_exercise(title: "Fractions")
    assignment_a = create_assignment(classroom: @a, assignable: exercise, by: teacher_a)
    assignment_c = create_assignment(classroom: @c, assignable: exercise, by: teacher_c)
    create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 75, classroom_assignment: assignment_a)
    sign_in_as @student

    send_change
    get student_archive_path

    assert_select "#student_archive_results li", 1 do
      assert_select "p", "Fractions"
      assert_select "[data-grade]", text: %r{15/20}
    end
    rows = css_select("#student_archive_classrooms li")
    assert_select rows.first, "p", "2nde C"
    assert_select rows.first, "span", "Actuelle"
    assert_select rows.last, "p", "2nde A"
    assert_select rows.last, "span", text: /\Adu .+ au .+\z/
    sign_out

    sign_in_as teacher_a
    get classroom_assignment_path(@a.public_id, assignment_a.public_id)

    assert_equal [ "0 / 0 fait" ], css_select("#follow_up_progress span.tabular-nums").map { it.text.strip }
    assert_no_match(/Awa/, response.body)
    sign_out

    sign_in_as teacher_c
    get classroom_assignment_path(@c.public_id, assignment_c.public_id)

    assert_equal [ "0 / 1 fait" ], css_select("#follow_up_progress span.tabular-nums").map { it.text.strip }
  end

  test "chained: the old classroom no longer lists the student, the new one counts them as new in its title, the old direction lists them" do
    teacher_a = create_teacher(school: @cocody, classrooms: [ @a ], first_name: "Ibrahim", last_name: "Traoré")
    teacher_c = create_teacher(school: @viateur, classrooms: [ @c ], first_name: "Moussa", last_name: "Diallo")
    create_student(classroom: @a, first_name: "Koffi", last_name: "Yao")
    roster = "classroom.classrooms.roster"
    sign_in_as @student

    send_change
    sign_out

    sign_in_as teacher_a
    get classroom_path(@a.public_id)

    assert_select "h2#classroom_roster_title", text: /#{I18n.t("#{roster}.title", count: 1)}/
    assert_select "#student_#{@student.public_id}", 0
    sign_out

    sign_in_as teacher_c
    get classroom_path(@c.public_id)

    # Maquette 10 : la ligne n'a plus de pastille « Nouveau » ; l'arrivée se lit dans le titre de la liste.
    assert_select "#student_#{@student.public_id}", 1
    assert_select "h2#classroom_roster_title span", text: I18n.t("#{roster}.new_count", count: 1)
    sign_out

    sign_in_as create_school_admin(school: @cocody, first_name: "Aya", last_name: "Brou")
    get school_admin_departed_students_path

    assert_select "#departed_students tbody tr th[scope=row]", "Awa Koné"
  end
end
