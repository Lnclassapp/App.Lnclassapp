require "test_helper"

# DS-09, DS-10, DS-11 (ADR-0065, UDR-0052), AD-02 to AD-08 (UDR-0072): the direction's home and the page of a classroom,
# read by the school management of its own school only. Another school's classroom is a 404, any other role a 403, a
# visitor signs in first.
class SchoolAdmin::ClassroomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @admin = create_school_admin(school: @school)
    @level = create_level(name: "2nde", position: 5)
    @classroom = create_classroom(school: @school, level: @level, name: "2nde C 1")
    @other = create_classroom(school: create_school(name: "Lycée Classique d'Abidjan"), level: @level, name: "Tle D 9")
    create_student(classroom: @other, first_name: "Intrus", last_name: "Ailleurs")
  end

  def tc(key, **) = I18n.t("school_admin.classrooms.#{key}", **)
  def pages = [ school_admin_classrooms_path, school_admin_classroom_path(@classroom.public_id) ]

  def handed_in(student, assignment, score)
    create_exercise_session(student:, status: "completed", score_percent: score, classroom_assignment_id: assignment.id)
  end

  test "DS-11: a student, a teacher, a team member and a detached school admin receive 403" do
    [ create_student, create_teacher(school: @school), create_team_member, create_user(role: "school_admin") ].each do |outsider|
      sign_in_as outsider

      pages.each do |path|
        get path
        assert_response :forbidden, "#{outsider.role} on #{path}"
      end
      sign_out
    end
  end

  test "DS-11: a visitor is sent to sign in" do
    pages.each do |path|
      get path
      assert_redirected_to new_session_path
    end
  end

  test "DS-10: another school's classroom, an unknown one and an archived one give 404" do
    archived = create_classroom(school: @school, level: @level, name: "2nde C 9", status: "archived")
    sign_in_as @admin

    [ @other.public_id, "inconnu", archived.public_id ].each do |public_id|
      get school_admin_classroom_path(public_id)
      assert_response :not_found, public_id
    end
  end

  # AD-02 to AD-08, AD-20, AD-22 (UDR-0072 §3.2 to §3.4, §3.11): the home of the direction, greeting by first name, then the
  # school card, the level bubbles and the deferred activity, in this order.
  def card(key, **) = tc("school_card.#{key}", **)
  def levels_t(key, **) = tc("levels.#{key}", **)
  def signal(color, key) = I18n.t("school_admin.signals.#{color}.#{key}")

  # Students of a classroom, each handing in the first `handed` assignments given.
  def fill(klass, students:, assignments:, handed: [])
    teacher = create_teacher(school: @school, classrooms: [ klass ])
    given = Array.new(assignments) { create_assignment(classroom: klass, by: teacher) }
    Array.new(students) do |index|
      create_student(classroom: klass).tap { |student| given.first(handed.fetch(index, 0)).each { handed_in(student, it, 50) } }
    end
  end

  test "AD-02, AD-20, AD-22: the home greets by first name, under « Accueil », with one h1 and the four sections in order" do
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_response :success
    assert_select "title", text: "#{tc('index.page_title')} · Direction · Lnclass"
    assert_select "h1", count: 1, text: tc("index.greeting", name: @admin.first_name)
    assert_select "nav a[aria-current=page][href=?]", school_admin_classrooms_path, text: I18n.t("shared.navigation.home")
    assert_select "main div.grid.gap-5 > div[id]", count: 3 do |sections|
      assert_equal %w[direction_home_school direction_home_levels direction_home_activity], sections.map { it["id"] }
    end
    assert_select "main h2", count: 3
    assert_select "#student_work, table", count: 0
    assert_no_match(/Travail des élèves/, response.body)
  end

  test "AD-02: the school card names the school, its type and year, and counts classrooms, each student once, and teachers" do
    @school.update!(school_type: "private")
    second = create_classroom(school: @school, level: @level, name: "2nde C 2")
    create_classroom(school: @school, level: @level, name: "2nde C 9", status: "archived")
    both = create_student(classroom: @classroom)
    Orm::ClassroomStudent.create!(classroom: second, student: both, primary: false, joined_at: Time.current)
    create_student(classroom: second)
    create_teacher(school: @school, classrooms: [ @classroom, second ])
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_select "#direction_home_school" do
      assert_select "h2", text: "Lycée Moderne de Bouaké"
      assert_select "p", text: card("subtitle", type: "Privé", year: Entities::Classroom::SchoolYear.current(Date.current))
      assert_select "ul#direction_home_figures.grid.grid-cols-3 > li.rounded-ln.bg-mist", count: 3
      assert_select "ul#direction_home_figures li:nth-child(1)", text: /\A\s*2\s+#{card('figures.classrooms', count: 2)}\s*\z/
      assert_select "ul#direction_home_figures li:nth-child(2)", text: /\A\s*2\s+#{card('figures.students', count: 2)}\s*\z/
      assert_select "ul#direction_home_figures li:nth-child(3)", text: /\A\s*1\s+#{card('figures.teachers', count: 1)}\s*\z/
    end
    assert_equal [ "classe", "classes", "élève", "élèves", "enseignant", "enseignants" ],
                 %w[classrooms students teachers].flat_map { |key| [ 1, 2 ].map { card("figures.#{key}", count: it) } }
    assert_no_match(/Tle D 9|Intrus|Lycée Classique/, response.body)
  end

  test "AD-03: four alerts in order, each naming its classrooms, with the link where the direction acts" do
    create_student(classroom: @classroom)
    empty = create_classroom(school: @school, level: @level, name: "2nde C 2")
    create_teacher(school: @school, classrooms: [ empty ])
    fill(create_classroom(school: @school, level: @level, name: "2nde C 3"), students: 13, assignments: 1, handed: Array.new(4, 1))
    create_teacher(school: @school)
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_select "#direction_home_school" do
      assert_select "h3", text: card("alerts_title")
      assert_select "ul#direction_home_alerts > li", count: 4 do |items|
        assert_equal %w[alert_without_teacher alert_without_students alert_red_signal alert_teachers_without_classroom],
                     items.map { it["id"] }
      end
      assert_select "#alert_without_teacher", text: /#{card('alerts.without_teacher', count: 1, names: '2nde C 1')}/
      assert_select "#alert_without_teacher a[href=?]", school_admin_school_path(anchor: "school_link"), text: card("links.invite")
      assert_select "#alert_without_students", text: card("alerts.without_students", count: 1, names: "2nde C 2")
      assert_select "#alert_red_signal", text: card("alerts.red_signal", count: 1, names: "2nde C 3")
      assert_select "#alert_without_students a, #alert_red_signal a", count: 0
      assert_select "#alert_teachers_without_classroom", text: /#{card('alerts.teachers_without_classroom', count: 1)}/
      assert_select "#alert_teachers_without_classroom a[href=?]", school_admin_teachers_path, text: card("links.teachers")
      assert_select "li > span.bg-warning-soft.text-warning svg[aria-hidden=true]", count: 4
      assert_select "#direction_home_all_clear", count: 0
    end
    assert_equal "1 classe rend moins de 40 % des devoirs : 2nde C 3", card("alerts.red_signal", count: 1, names: "2nde C 3")
  end

  test "AD-03: an alert names three classrooms at most, by name, then « et N autres »; two or three names read as a sentence" do
    names = [ "2nde C 2", "2nde C 3", "2nde C 4", "2nde C 5" ]
    names.each { create_classroom(school: @school, level: @level, name: it) }
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_select "#alert_without_teacher", text: /5 classes sans enseignant : 2nde C 1, 2nde C 2, 2nde C 3 et 2 autres/
    assert_select "#alert_without_students", text: /5 classes sans élève : 2nde C 1, 2nde C 2, 2nde C 3 et 2 autres/

    # L'accueil est gardé 5 minutes (AD-23) : chaque nouvelle lecture ici part d'un cache vide.
    Orm::Classroom.where(name: names.last(2)).destroy_all
    Rails.cache.clear
    get school_admin_classrooms_path

    assert_select "#alert_without_teacher", text: /3 classes sans enseignant : 2nde C 1, 2nde C 2 et 2nde C 3/

    Orm::Classroom.where(name: "2nde C 2").destroy_all
    Rails.cache.clear
    get school_admin_classrooms_path

    assert_select "#alert_without_teacher", text: /2 classes sans enseignant : 2nde C 1 et 2nde C 3/
    assert_equal "a, b et 1 autre", card("alerts.names_more", names: "a, b", count: 1)
  end

  test "AD-04: an inactive school alerts first, and leads to the « Établissement » page" do
    @school.update!(status: "inactive")
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_response :success
    assert_select "ul#direction_home_alerts > li:first-child#alert_inactive" do
      assert_select "span", text: /#{Regexp.escape(card('alerts.inactive'))}/
      assert_select "a[href=?]", school_admin_school_path, text: card("links.school")
    end
  end

  test "AD-05: without alert the card says « Rien à signaler », and its footer leads to « Établissement » and « Anciens élèves »" do
    fill(@classroom, students: 2, assignments: 1, handed: [ 1 ])
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_select "#direction_home_school" do
      assert_select "ul#direction_home_alerts", count: 0
      assert_select "p#direction_home_all_clear.text-success", text: card("all_clear") do
        assert_select "svg[aria-hidden=true]", count: 1
      end
      assert_select "div.border-t a", count: 2
      assert_select "div.border-t a[href=?]", school_admin_school_path, text: card("links.school")
      assert_select "div.border-t a#departed-students-link[href=?]", school_admin_departed_students_path, text: card("links.departed")
    end
  end

  test "AD-06: one bubble per level with an active classroom, by level, each with its drawing and leading to its level" do
    sixth = create_level(name: "6ème", position: 1)
    third = create_level(name: "3ème", position: 4)
    final = create_level(name: "Tle", position: 7)
    create_level(name: "5ème", position: 2).then { create_classroom(school: @school, level: it, name: "5ème 1", status: "archived") }
    create_classroom(school: @school, level: final, name: "Tle D 1", series: create_series(name: "D"))
    create_classroom(school: @school, level: final, name: "Tle C 1", series: create_series(name: "C"))
    create_classroom(school: @school, level: third, name: "3ème 1")
    create_classroom(school: @school, level: sixth, name: "6ème 1")
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_select "#direction_home_levels h2", text: levels_t("title")
    assert_select "nav#direction_home_level_bubbles[aria-label=?] ul.grid.grid-cols-4 > li", levels_t("label"), count: 4 do |items|
      assert_equal %w[level_6eme level_3eme level_2nde level_tle], items.map { it.at_css("a")["id"] }
    end
    { "6eme" => "6ème", "3eme" => "3ème", "2nde" => "2nde", "tle" => "Tle" }.each do |slug, name|
      assert_select "a#level_#{slug}[href=?]", school_admin_level_path(slug) do
        assert_select "img[src^=?][alt='']", "/assets/levels/#{slug}"
        assert_select "span", text: name
      end
    end
    assert_select "a#level_tle span.sr-only", text: levels_t("sr_level", count: 2)
    assert_select "a#level_6eme span.sr-only", text: levels_t("sr_level", count: 1)
    assert_no_match(/5ème/, response.body)
  end

  test "AD-07, AD-22: a level that hands in 55 % carries a yellow dot, said in the bubble's name, and the legend explains it" do
    third = create_level(name: "3ème", position: 4)
    fill(create_classroom(school: @school, level: third, name: "3ème 1"), students: 5, assignments: 2, handed: [ 2, 2, 1, 1 ])
    fill(create_classroom(school: @school, level: third, name: "3ème 2"), students: 5, assignments: 2, handed: [ 2, 2, 1 ])
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_select "a#level_3eme" do
      assert_select "span.relative > span.bg-signal-yellow[aria-hidden=true]", count: 1
      assert_select "span.sr-only", text: "#{levels_t('sr_level', count: 2)}#{levels_t('sr_rate', rate: 55)}#{signal(:yellow, :sr)}"
    end
    assert_equal ", 2 classes, taux de rendu 55 %, signal jaune",
                 "#{levels_t('sr_level', count: 2)}#{levels_t('sr_rate', rate: 55)}#{signal(:yellow, :sr)}"
    assert_select "a#level_2nde [class*=bg-signal]", count: 0
    assert_select "a#level_2nde span.sr-only", text: levels_t("sr_level", count: 1)
    assert_select "#direction_home_levels #signal_legend" do
      assert_select "details summary span.sr-only", text: "Aide : #{I18n.t('school_admin.signals.legend_title')}"
      assert_select "details div", text: tc("tips.submission_rate")
      %i[green yellow red].each { assert_select "span", text: signal(it, :legend) }
    end
    assert_select "[title]", count: 0
  end

  test "AD-07: without any dot, the levels have no legend" do
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_select "nav#direction_home_level_bubbles li", count: 1
    assert_select "#signal_legend", count: 0
  end

  test "AD-08: without an active classroom this year, « Niveaux » says so and leads to « Établissement »" do
    @classroom.update!(status: "archived", archived_at: Time.current)
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_response :success
    assert_select "ul#direction_home_figures li:nth-child(1)", text: /0\s+#{card('figures.classrooms', count: 0)}/
    assert_select "#direction_home_levels" do
      assert_select "nav", count: 0
      assert_select "p", text: levels_t("empty.title")
      assert_select "p", text: levels_t("empty.description")
      assert_select "a[href=?]", school_admin_school_path, text: levels_t("empty.action")
    end
  end

  test "AD-17 (home side): the recent activity loads later, in a lazy frame towards the activity of the school" do
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_select "#direction_home_activity" do
      assert_select "h2", text: tc("index.activity.title")
      assert_select "p", text: tc("index.activity.subtitle")
      assert_select "turbo-frame#direction_home_activity_feed[src=?][loading=lazy][target=_top]", school_admin_activity_path do
        assert_select "[role=status][aria-busy=true]", count: 1
      end
    end
  end

  test "DS-09: the classroom page shows its figures, then each student handed in over given and their average" do
    teacher = create_teacher(school: @school)
    given = create_assignment(classroom: @classroom, by: teacher)
    create_assignment(classroom: @classroom, by: teacher)
    aya = create_student(classroom: @classroom, first_name: "Aya", last_name: "Bamba")
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Diallo")
    handed_in(aya, given, 72)
    sign_in_as @admin

    get school_admin_classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "main nav[aria-label=?] a[href=?]", I18n.t("components.back_link.label"), school_admin_level_path("2nde"),
                  text: "2nde"
    assert_select "h1", count: 1, text: "2nde C 1"
    assert_select "p", text: tc("show.subtitle", level: "2nde", count: 2)
    assert_select "nav a[aria-current=page]", text: I18n.t("shared.navigation.home")
    assert_select "ul#classroom_figures li", count: 3
    assert_select "ul#classroom_figures li", text: /2\s+#{tc('show.figures.assignments')}/
    assert_select "ul#classroom_figures li", text: /25 %\s+#{tc('show.figures.submission_rate')}/
    assert_select "#classroom_students caption.sr-only", text: tc("show.caption", classroom: "2nde C 1")
    assert_select "#classroom_students th[scope=col]", count: 3
    assert_select "tr#student_0" do
      assert_select "th[scope=row]", text: "Aya Bamba"
      assert_select "td", text: "1 / 2"
      assert_select "td", text: "72 %"
    end
    assert_select "tr#student_1" do
      assert_select "th[scope=row]", text: "Koffi Diallo"
      assert_select "td", text: "0 / 2"
      assert_select "td span[aria-hidden=true]", text: "—"
    end
    assert_no_match(/#{aya.public_id}|#{aya.contact}/, response.body)
    assert_select "main form", count: 1
    assert_select "main form#student-work-search input[name=q]", count: 1
  end

  test "a classroom without student keeps its figures and says it is empty" do
    sign_in_as @admin

    get school_admin_classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "ul#classroom_figures li", count: 3
    assert_select "#classroom_students table", count: 0
    assert_select "#classroom_students", text: /#{tc('show.empty')}/
  end

  # AD-13 (UDR-0072 §3.9): the back link of a classroom leads to the page of its level, named after it.
  test "AD-13, FU-10, FU-11: the classroom page returns to its level by the common back link, never an arrow button" do
    sign_in_as @admin

    get school_admin_classroom_path(@classroom.public_id)

    assert_select "main a", minimum: 1 do |links|
      assert_equal school_admin_level_path("2nde"), links.first["href"]
      assert_equal "2nde", links.first.text.strip
    end
    assert_select "main nav[aria-label=?] + div h1", I18n.t("components.back_link.label"), text: "2nde C 1"
    assert_no_match(/arrow-left/, response.body)
  end

  test "FU-06: both pages name the tab « Page · Direction · Lnclass »" do
    sign_in_as @admin

    get school_admin_classrooms_path
    assert_select "title", text: "#{tc('index.page_title')} · Direction · Lnclass"

    get school_admin_classroom_path(@classroom.public_id)
    assert_select "title", text: "2nde C 1 · Direction · Lnclass"
  end

  test "FU-21: the classroom page explains its figures, the student average and « — »" do
    create_student(classroom: @classroom, first_name: "Aya", last_name: "Bamba")
    sign_in_as @admin

    get school_admin_classroom_path(@classroom.public_id)

    assert_select "ul#classroom_figures details div", text: tc("tips.submission_rate")
    assert_select "ul#classroom_figures details div", text: tc("tips.average")
    assert_select "#classroom_students th[scope=col]", text: /#{tc('show.columns.average')}/ do
      assert_select "details summary span.sr-only", text: "Aide : #{tc('show.columns.average')}"
      assert_select "details div", text: tc("tips.student_average")
    end
    assert_select "#classroom_students details div", text: tc("tips.missing")
  end

  test "FU-49: the search lists only the matching students of this classroom, without case nor accents" do
    teacher = create_teacher(school: @school)
    given = create_assignment(classroom: @classroom, by: teacher)
    aya = create_student(classroom: @classroom, first_name: "Aya", last_name: "Bamba")
    create_student(classroom: @classroom, first_name: "Fanta", last_name: "Diabaté")
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Diallo")
    handed_in(aya, given, 72)
    sign_in_as @admin

    get school_admin_classroom_path(@classroom.public_id, q: "  DIABATE ")

    assert_response :success
    assert_select "form#student-work-search[method=get][role=search][aria-label=?][data-controller=search]",
                  tc("show.search.label") do |form|
      assert_equal "student_work_students", form.first["data-turbo-frame"]
      assert_select "input[name=q][value=DIABATE][data-action~='search#queue']"
      assert_select "[data-search-target=button]"
    end
    assert_select "turbo-frame#student_work_students" do
      assert_select "[aria-live=polite]", text: tc("show.search.count", count: 1)
      assert_select "tbody tr", count: 1
      assert_select "tbody th[scope=row]", text: "Fanta Diabaté"
    end
    assert_select "p", text: tc("show.subtitle", level: "2nde", count: 3)
    assert_select "ul#classroom_figures li", text: /33 %\s+#{tc('show.figures.submission_rate')}/
    assert_no_match(/Aya Bamba|Koffi Diallo|Intrus/, response.body)
  end

  test "FU-49: the search matches the start of a first name and never a student of another classroom" do
    create_student(classroom: @classroom, first_name: "Aya", last_name: "Bamba")
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Diallo")
    sign_in_as @admin

    get school_admin_classroom_path(@classroom.public_id, q: "int")

    assert_select "turbo-frame#student_work_students" do
      assert_select "[aria-live=polite]", text: tc("show.search.count", count: 0)
      assert_select "table", count: 0
      assert_select "h2, h3, p", text: tc("show.search.empty")
      assert_select "a[href=?][data-turbo-frame=_top]", school_admin_classroom_path(@classroom.public_id),
                    text: tc("show.search.clear")
    end
    assert_no_match(/Intrus/, response.body)

    get school_admin_classroom_path(@classroom.public_id, q: "aya")

    assert_select "#student_work_students tbody tr", count: 1
    assert_select "#student_work_students tbody th[scope=row]", text: "Aya Bamba"
  end

  test "FU-49: a classroom without student offers no search" do
    sign_in_as @admin

    get school_admin_classroom_path(@classroom.public_id, q: "aya")

    assert_select "form#student-work-search", count: 0
    assert_select "#classroom_students", text: /#{tc('show.empty')}/
  end

  # ID-10 (ADR-0077 §4.4, UDR-0070 §3.3, UDR-0072 §3.2): the arrival banner, between the greeting and the home's sections.
  def arrival(name, date, via) = tc("index.arrivals.line", name:, date:, via: tc("index.arrivals.via.#{via}"))
  def day(time) = I18n.l(time.to_date, format: :long).sub(/\A1 /, "1er ")

  test "ID-10: Kofi (10 days) reads the arrivals of Aya (2 days) and of the invited admin above the home's sections; Aya not hers" do
    kofi = create_school_admin(school: @school, first_name: "Kofi", last_name: "Yao", joined_via: "code", joined_at: 10.days.ago)
    aya = create_school_admin(school: @school, first_name: "Aya", last_name: "Koné", joined_via: "code", joined_at: 2.days.ago)
    create_school_admin(school: @school, first_name: "Gone", last_name: "Archivé", joined_via: "code", joined_at: 1.day.ago,
                        archived_at: 1.hour.ago)
    create_school_admin(school: create_school, first_name: "Zadi", last_name: "Ailleurs", joined_via: "code", joined_at: 1.day.ago)

    sign_in_as kofi
    get school_admin_classrooms_path

    assert_response :success
    assert_select "#staff_arrivals[role=status].mb-6.rounded-ln.bg-school\\/10.px-4.py-3.text-sm.text-ink + div.grid > #direction_home_school"
    assert_select "#staff_arrivals p", 2
    assert_select "#staff_arrivals p:nth-of-type(1)", text: arrival("#{@admin.first_name} #{@admin.last_name}", day(Time.current), :invitation)
    assert_select "#staff_arrivals p:nth-of-type(2)", text: arrival("Aya Koné", day(2.days.ago), :code)
    assert_select "#staff_arrivals button, #staff_arrivals a", 0
    [ "Archivé", "Ailleurs" ].each { assert_not_includes response.body, it }
    sign_out

    sign_in_as aya
    get school_admin_classrooms_path

    assert_select "#staff_arrivals p", 1
    assert_select "#staff_arrivals", text: /Aya Koné|Kofi Yao/, count: 0
  end

  test "ID-10: an arrival on the first of the month reads « 1er »" do
    travel_to Time.zone.local(2026, 10, 4, 9) do
      create_school_admin(school: @school, first_name: "Aya", last_name: "Koné", joined_via: "code", joined_at: Time.zone.local(2026, 10, 1, 8))

      sign_in_as @admin
      get school_admin_classrooms_path

      assert_select "#staff_arrivals p", text: arrival("Aya Koné", "1er octobre 2026", :code)
    end
  end

  test "ID-10: no arrival within 7 days, no banner" do
    Orm::SchoolStaff.where(user_id: @admin.id).update_all(created_at: 8.days.ago)
    create_school_admin(school: @school, joined_via: "code", joined_at: 8.days.ago)

    sign_in_as @admin
    get school_admin_classrooms_path

    assert_response :success
    assert_select "#staff_arrivals", 0
  end
end
