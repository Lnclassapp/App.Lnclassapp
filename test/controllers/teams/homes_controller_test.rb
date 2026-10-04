require "test_helper"

# TR-09, CA-25 (UDR-0018): the team home. The old feed read an Orm constant that had disappeared, and the referential was
# only reachable from a tabbed dashboard served by two concurrent 12-hour caches. Since UDR-0068 §3.4 (RE-05), the
# referential has its own page, out of the home.
class Teams::HomesControllerTest < ActionDispatch::IntegrationTest
  RECENT_FRAME = "team_home_recent_content".freeze

  setup do
    @member = create_team_member(first_name: "Aya")
  end

  def tl(key, **) = I18n.t("teams.homes.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  # A figure reads as its number, then its label: « 2 établissements ».
  def figure(key, count) = including("#{count} #{tl(key, count:)}")
  def get_recent_content = get(team_home_path, headers: { "Turbo-Frame" => RECENT_FRAME })

  test "a teacher, a student and a school admin receive 403" do
    [ create_teacher, create_student, create_user(role: "school_admin") ].each do |user|
      sign_in_as user

      get team_home_path
      assert_response :forbidden
      get_recent_content
      assert_response :forbidden
      sign_out
    end
  end

  test "a team member whose second factor is not verified is sent to the second factor" do
    post session_path, params: { session: { contact: @member.contact, pin: "2468" } }

    get team_home_path

    assert_redirected_to new_identity_second_factor_path
  end

  test "the team sees the counts of DRENA, schools and classrooms of the school year" do
    school = create_school
    create_school(drena: school.drena)
    create_drena
    create_classroom(school:)
    create_classroom(school:, status: "archived")
    sign_in_as @member

    get team_home_path

    assert_response :success
    assert_select "h1", text: including(tl("show.greeting", name: "Aya"))
    assert_select "#team_home_regions" do
      assert_select "*", text: figure("show.drenas", 2)
      assert_select "*", text: figure("show.schools", 2)
      assert_select "*", text: figure("show.classrooms", 1)
      assert_select "a[href='#{schools_path}']"
    end
  end

  # RE-05 (UDR-0068 §3.4): the referential has its own page (test/controllers/teams/referentials_controller_test.rb); the
  # home keeps « Régions éducatives » then « Activité récente », and the « Importer » shortcut.
  test "RE-05: the home reads « Régions éducatives » then « Activité récente », and no Référentiel section" do
    seed_referential
    sign_in_as @member

    get team_home_path

    assert_response :success
    # The recent content is a lazy frame: the page received holds the headings of the two sections, in this order, alone.
    assert_equal [ tl("show.regions_title"), tl("show.activity_title") ], css_select("main#main h2").map { it.text.strip }
    assert_select "#team_home_referential", 0
    assert_select "#team_referential", 0
    [ drenas_path, levels_path, series_index_path, materials_path, classroom_plan_path ].each do |path|
      assert_select "main#main a[href='#{path}']", 0
    end
    assert_select "main#main li[id^=level_]", 0
    assert_select "#team_home_shortcuts a[href='#{teams_imports_path}']", text: including(tl("shortcuts.imports"))
  end

  test "the shortcuts: new course and invitation in the modal, schools, imports and account unlocking" do
    sign_in_as @member

    get team_home_path

    assert_select "#team_home_shortcuts" do
      assert_select "a[href='#{new_teams_course_path}'][data-turbo-frame=modal]", text: including(tl("shortcuts.new_course"))
      assert_select "a[href='#{schools_path}']", text: including(tl("shortcuts.schools"))
      assert_select "a[href='#{teams_imports_path}']", text: including(tl("shortcuts.imports"))
      assert_select "a[href='#{new_teams_invitation_path}'][data-turbo-frame=modal]", text: including(tl("shortcuts.invite"))
      assert_select "a[href='#{teams_account_lookup_path}']", text: including(tl("shortcuts.unlock_account"))
      assert_select "a[href='#{teams_growth_path}']", text: including(tl("shortcuts.growth"))
    end
  end

  test "a content member does not see the invitation shortcut, reserved to admins" do
    sign_in_as create_team_member(team_role: "content")

    get team_home_path

    assert_select "#team_home_shortcuts a", 6
    assert_select "a[href='#{new_teams_invitation_path}']", 0
  end

  test "BL-08 (UDR-0067 §3.1): the « Blog » shortcut, after « Croissance » and before the invitation, for admin and content" do
    sign_in_as @member

    get team_home_path

    shortcuts = css_select("#team_home_shortcuts a").pluck("href")
    assert_equal shortcuts.index(teams_growth_path) + 1, shortcuts.index(teams_articles_path)
    assert_equal shortcuts.index(teams_articles_path) + 1, shortcuts.index(new_teams_invitation_path)
    assert_select "a#team_home_blog_shortcut[href='#{teams_articles_path}']:not([data-turbo-frame])", text: including(tl("shortcuts.blog"))
    sign_out

    sign_in_as create_team_member(team_role: "content")
    get team_home_path
    assert_select "a#team_home_blog_shortcut[href='#{teams_articles_path}']"
  end

  test "BL-08: a field member does not see the « Blog » shortcut" do
    sign_in_as create_team_member(team_role: "field")

    get team_home_path

    assert_response :success
    assert_select "#team_home_shortcuts"
    assert_select "#team_home_blog_shortcut", 0
    assert_select "a[href='#{teams_articles_path}']", 0
  end

  test "the recent content is a lazy frame, which receives only its partial" do
    create_course(name: "Génétique et évolution", status: "draft")
    sign_in_as @member

    get team_home_path

    assert_select "#team_home_activity turbo-frame##{RECENT_FRAME}[loading=lazy][src='#{team_home_path}']"
    assert_no_match "Génétique et évolution", response.body

    get_recent_content

    assert_response :success
    assert_select "turbo-frame##{RECENT_FRAME}[target=_top]"
    assert_select "#team_home_regions", 0
    assert_match "Génétique et évolution", response.body
  end

  test "the five last courses, exercises and imports, every status, each leading to its page" do
    course = create_course(name: "Génétique et évolution", status: "draft",
                           material: create_material(name: "SVT", category: "science"))
    exercise = create_exercise(title: "Méiose", status: "archived", questions: 0)
    report = create_import_report(kind: "schools", status: "rejected")
    6.times { create_course }
    sign_in_as @member

    get_recent_content

    assert_select "#team_home_recent_courses li", 5
    assert_select "#team_home_recent_courses a[href='#{course_path(course.slug)}']", 0
    assert_select "#team_home_recent_exercises li#recent_exercise_#{exercise.public_id}" do
      assert_select "a[href='#{exercise_path(exercise.public_id)}']", text: including("Méiose")
      assert_select "*", text: including(I18n.t("catalog.content_status.archived"))
    end
    assert_select "#team_home_recent_imports li#recent_import_#{report.public_id}" do
      assert_select "a[href='#{teams_import_path(report.public_id)}']", text: including(I18n.t("import_kinds.schools"))
      assert_select "*", text: including(I18n.t("teams.imports.statuses.rejected"))
    end

    Orm::Course.where.not(id: course.id).update_all(updated_at: 1.day.ago)
    get_recent_content

    assert_select "#team_home_recent_courses li#recent_course_#{course.slug}" do
      assert_select "a[href='#{course_path(course.slug)}']", text: including("Génétique et évolution")
      assert_select "*", text: including("SVT")
      assert_select "*", text: including(I18n.t("catalog.content_status.draft"))
    end
  end

  test "an import whose file is not attached yet is named by its kind alone" do
    report = create_import_report(kind: "exercises", status: "queued")
    report.update!(files: [ { "name" => "exercices.json", "byte_size" => 2, "status" => "pending" } ])
    other = create_import_report(kind: "schools", status: "queued")
    sign_in_as @member

    get_recent_content

    assert_select "li#recent_import_#{report.public_id}", text: including("exercices.json")
    assert_select "li#recent_import_#{other.public_id}", text: including(I18n.t("import_kinds.schools"))
    assert_select "li#recent_import_#{other.public_id} *", text: including(".json"), count: 0
  end

  test "a running generation of the classrooms is « Génération en cours », not « Import en cours »" do
    running = create_import_report(kind: "classrooms", checksum_sha256: nil, status: "importing")
    sign_in_as @member

    get_recent_content

    assert_select "li#recent_import_#{running.public_id}", text: including("Génération en cours")
    assert_select "li#recent_import_#{running.public_id}", text: including("Import en cours"), count: 0
  end

  test "nothing created yet: each recent list has its empty state" do
    sign_in_as @member

    get_recent_content

    assert_select "#team_home_recent_courses", text: including(tl("recent_content.courses_empty"))
    assert_select "#team_home_recent_exercises", text: including(tl("recent_content.exercises_empty"))
    assert_select "#team_home_recent_imports", text: including(tl("recent_content.imports_empty"))
  end

  # ADR-0036, amendement (2) : le rappel des demandes de suppression, pour l'admin seul ; ambre au 25e jour, en retard au 31e.
  def deletion_request(requested_on, status: "pending")
    closed = { closed_at: Time.current, closed_by: @member } unless status == "pending"
    Orm::AccountDeletionRequest.create!(user: create_student, requested_on:, recorded_by: @member, status:, **closed.to_h)
  end

  test "without pending deletion request, no card" do
    deletion_request(Date.current - 40, status: "processed")
    sign_in_as @member

    get team_home_path

    assert_select "#team_home_deletion_requests", 0
  end

  test "the admin sees the number of pending deletion requests and the nearest due date, leading to the list" do
    travel_to Time.zone.local(2026, 10, 2, 10) do
      deletion_request(Date.new(2026, 9, 20))
      deletion_request(Date.new(2026, 9, 10))
      deletion_request(Date.new(2026, 8, 1), status: "cancelled")
      sign_in_as @member

      get team_home_path

      assert_select "a#team_home_deletion_requests[href='#{teams_deletion_requests_path}']" do
        assert_select "h2", tl("deletion_requests.title")
        assert_select "p", tl("deletion_requests.pending", count: 2)
        assert_select "span:not(.bg-warning-soft)", I18n.t("teams.deletion_requests.due.before", date: I18n.l(Date.new(2026, 10, 10), format: :due_short))
      end
    end
  end

  test "the card turns amber on the 25th day, and says « En retard » on the 31st" do
    deletion_request(Date.new(2026, 9, 1))
    sign_in_as @member
    due = I18n.l(Date.new(2026, 10, 1), format: :due_short)

    { 24 => [ "before", 0 ], 25 => [ "before", 1 ], 31 => [ "late", 1 ] }.each do |day, (key, amber)|
      travel_to Time.zone.local(2026, 9, 1, 10) + day.days do
        get team_home_path

        assert_select "#team_home_deletion_requests span", I18n.t("teams.deletion_requests.due.#{key}", date: due)
        assert_select "#team_home_deletion_requests span.bg-warning-soft", amber
      end
    end
  end

  test "a team member content or field sees no deletion card" do
    deletion_request(Date.current - 26)

    %w[content field].each do |team_role|
      sign_in_as create_team_member(team_role:)
      get team_home_path
      assert_response :success
      assert_select "#team_home_deletion_requests", 0
      sign_out
    end
  end

  test "ID-21 (UDR-0070 §3.5): 6 removed directions of two schools: the 5 most recent, each leading to its school, then « Et 1 autre »" do
    travel_to Time.zone.local(2026, 10, 4, 10) do
      bouake = create_school(name: "Lycée Moderne de Bouaké")
      korhogo = create_school(name: "Collège de Korhogo")
      removed = 6.times.map do |index|
        create_school_admin(school: index.even? ? bouake : korhogo, first_name: "Direction#{index}", last_name: "Koné",
                            archived_at: (index + 1).days.ago)
      end
      deletion_request(Date.current - 3)
      sign_in_as @member

      get team_home_path

      assert_select "#team_home_archived_staff" do
        assert_select "h2", tl("archived_staff.title")
        assert_select "*", text: tl("archived_staff.subtitle")
        assert_select "li", 5
        assert_select "li a[href='#{school_path(bouake.public_id)}']",
                      text: tl("archived_staff.line", name: "Direction0 Koné", school: "Lycée Moderne de Bouaké", date: "3 octobre 2026")
        assert_select "li a[href='#{school_path(korhogo.public_id)}']", text: /Direction1 Koné · Collège de Korhogo/
        assert_select "li", text: /#{removed.last.first_name}/, count: 0
        assert_select "p#team_home_archived_staff_more", tl("archived_staff.more", count: 1)
      end
      assert_operator response.body.index("team_home_deletion_requests"), :<, response.body.index("team_home_archived_staff")
    end
  end

  test "ID-21: a field member sees the removed directions; a content member does not; without any, no card" do
    create_school_admin(archived_at: 1.day.ago)

    sign_in_as create_team_member(team_role: "field")
    get team_home_path
    assert_select "#team_home_archived_staff li", 1
    assert_select "#team_home_archived_staff_more", 0
    sign_out

    sign_in_as create_team_member(team_role: "content")
    get team_home_path
    assert_response :success
    assert_select "#team_home_archived_staff", 0
    sign_out

    Orm::SchoolStaff.update_all(archived_at: nil, archived_by_id: nil)
    sign_in_as @member
    get team_home_path
    assert_select "#team_home_archived_staff", 0
  end
end
