require "test_helper"

# TR-09, CA-25 (UDR-0018): the team home. The old feed read an Orm constant that had disappeared, and the referential was
# only reachable from a tabbed dashboard served by two concurrent 12-hour caches.
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

  test "the referential shows the counts of DRENA, levels, series and materials, each leading to its screen" do
    create_drena
    tle = create_level(name: "Tle", position: 7)
    create_level(name: "6ème", position: 1)
    link_level_series(level: tle, series: create_series(name: "D"))
    create_series(name: "A1")
    3.times { create_material }
    sign_in_as @member

    get team_home_path

    assert_select "#team_home_referential" do
      assert_select "h2", text: tl("referential.title")
      { drenas_path => figure("referential.drenas", 1), levels_path => figure("referential.levels", 2),
        series_index_path => figure("referential.series", 2), materials_path => figure("referential.materials", 3) }
        .each { |path, label| assert_select "a[href='#{path}']", text: label }
      assert_select "li", text: including("6ème")
      assert_select "li", text: including("Tle") do
        assert_select "*", text: "D"
      end
      assert_select "li", text: including(tl("referential.no_series"))
    end
  end

  test "the counts follow the last creation, with no cache" do
    sign_in_as @member
    get team_home_path
    assert_select "#team_home_referential a[href='#{levels_path}']", text: figure("referential.levels", 0)

    create_level

    get team_home_path
    assert_select "#team_home_referential a[href='#{levels_path}']", text: figure("referential.levels", 1)
  end

  test "an empty referential says so and still leads to each screen" do
    sign_in_as @member

    get team_home_path

    assert_select "#team_home_referential" do
      assert_select "*", text: including(tl("referential.levels_empty"))
      assert_select "a[href='#{levels_path}']"
    end
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
    end
  end

  test "a content member does not see the invitation shortcut, reserved to admins" do
    sign_in_as create_team_member(team_role: "content")

    get team_home_path

    assert_select "#team_home_shortcuts a", 4
    assert_select "a[href='#{new_teams_invitation_path}']", 0
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
    report.source.attach(io: StringIO.new("{}"), filename: "exercices.json", content_type: "application/json")
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
end
