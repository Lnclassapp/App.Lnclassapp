require "test_helper"

# DS-07, DS-09, DS-10, DS-11 (ADR-0065, UDR-0052): « Travail des élèves » and the page of a classroom, read by the school
# management of its own school only. Another school's classroom is a 404, any other role a 403, a visitor signs in first.
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

  test "DS-07, DS-10: the list shows each classroom of the school with its figures, never another school's" do
    teacher = create_teacher(school: @school)
    given = create_assignment(classroom: @classroom, by: teacher)
    create_assignment(classroom: @classroom, by: teacher)
    aya = create_student(classroom: @classroom)
    3.times { create_student(classroom: @classroom) }
    handed_in(aya, given, 80)
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_response :success
    assert_select "h1", count: 1, text: tc("index.title")
    assert_select "p", text: tc("index.subtitle", school: "Lycée Moderne de Bouaké",
                                                  year: Entities::Classroom::SchoolYear.current(Date.current))
    assert_select "nav a[aria-current=page]", text: I18n.t("shared.navigation.student_work")
    assert_select "#student_work table caption.sr-only", text: tc("index.caption")
    assert_select "#student_work th[scope=col]", count: 5
    assert_select "tr#classroom_#{@classroom.public_id}" do
      assert_select "th[scope=row] a[href=?]", school_admin_classroom_path(@classroom.public_id), text: "2nde C 1"
      assert_select "th[scope=row] span", text: "2nde"
      assert_select "td", text: "4"
      assert_select "td", text: "2"
      assert_select "td", text: "13 %"
      assert_select "td span[aria-hidden=true]", text: "—"
      assert_select "td span.sr-only", text: tc("not_computed")
    end
    assert_select "#student_work", text: /#{tc('legend.label')}/
    assert_select "tbody tr", count: 1
    assert_no_match(/Tle D 9|Intrus|Lycée Classique/, response.body)
  end

  test "the list of a school without classroom this year says so" do
    @classroom.destroy!
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_response :success
    assert_select "#student_work table", count: 0
    assert_select "#student_work", text: /#{tc('index.empty')}/
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
    assert_select "main nav[aria-label=?] a[href=?]", I18n.t("components.back_link.label"), school_admin_classrooms_path,
                  text: tc("show.back")
    assert_select "h1", count: 1, text: "2nde C 1"
    assert_select "p", text: tc("show.subtitle", level: "2nde", count: 2)
    assert_select "nav a[aria-current=page]", text: I18n.t("shared.navigation.student_work")
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

  # Memo of remediation-comptee-faite: Aya fails X at 25 %, a gap opens on the fiche (ADR-0043), she then does Y in
  # remediation at 80 % (StartExerciseSession#new_session). Y is handed in on both pages, and the 80 % is in her average.
  test "an exercise done in remediation is handed in, and its score counts in the student's average" do
    teacher = create_teacher(school: @school)
    essential = create_essential
    x, y = Array.new(2) { create_exercise(essential:) }
    given_x, given_y = [ x, y ].map { create_assignment(classroom: @classroom, assignable: it, by: teacher) }
    aya = create_student(classroom: @classroom, first_name: "Aya", last_name: "Bamba")
    failed = create_exercise_session(student: aya, exercise: x, status: "completed", score_percent: 25,
                                     classroom_assignment_id: given_x.id)
    create_exercise_session(student: aya, exercise: y, status: "completed", score_percent: 80, classroom_assignment_id: given_y.id,
                            gap: create_gap(student: aya, essential:, source_session: failed))
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_select "tr#classroom_#{@classroom.public_id} td", text: "100 %"

    get school_admin_classroom_path(@classroom.public_id)

    assert_select "ul#classroom_figures li", text: /100 %\s+#{tc('show.figures.submission_rate')}/
    assert_select "tr#student_0" do
      assert_select "th[scope=row]", text: "Aya Bamba"
      assert_select "td", text: "2 / 2"
      assert_select "td", text: "53 %"
    end
  end

  test "a classroom without student keeps its figures and says it is empty" do
    sign_in_as @admin

    get school_admin_classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "ul#classroom_figures li", count: 3
    assert_select "#classroom_students table", count: 0
    assert_select "#classroom_students", text: /#{tc('show.empty')}/
  end

  test "FU-10, FU-11: the classroom page returns to « Travail des élèves » by the common back link, never an arrow button" do
    sign_in_as @admin

    get school_admin_classroom_path(@classroom.public_id)

    assert_select "main a", minimum: 1 do |links|
      assert_equal school_admin_classrooms_path, links.first["href"]
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

  test "FU-21: the list explains « Taux de rendu », « Moyenne » and « — » with native <details>, readable without JavaScript" do
    sign_in_as @admin

    get school_admin_classrooms_path

    { submission_rate: "submission_rate", average: "average" }.each do |column, tip|
      assert_select "#student_work th[scope=col]", text: /#{tc("index.columns.#{column}")}/ do
        assert_select "details summary span.sr-only", text: "Aide : #{tc("index.columns.#{column}")}"
        assert_select "details div", text: tc("tips.#{tip}")
      end
    end
    assert_select "#student_work details summary span.sr-only", text: "Aide : #{tc('legend.label')}"
    assert_select "#student_work details div", text: tc("tips.missing")
    assert_select "[title]", count: 0
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

  # ID-10 (ADR-0077 §4.4, UDR-0070 §3.3): the arrival banner above « Travail des élèves ».
  def arrival(name, date, via) = tc("index.arrivals.line", name:, date:, via: tc("index.arrivals.via.#{via}"))
  def day(time) = I18n.l(time.to_date, format: :long).sub(/\A1 /, "1er ")

  test "ID-10: Kofi (10 days) reads the arrivals of Aya (2 days) and of the invited admin above #student_work; Aya not hers" do
    kofi = create_school_admin(school: @school, first_name: "Kofi", last_name: "Yao", joined_via: "code", joined_at: 10.days.ago)
    aya = create_school_admin(school: @school, first_name: "Aya", last_name: "Koné", joined_via: "code", joined_at: 2.days.ago)
    create_school_admin(school: @school, first_name: "Gone", last_name: "Archivé", joined_via: "code", joined_at: 1.day.ago,
                        archived_at: 1.hour.ago)
    create_school_admin(school: create_school, first_name: "Zadi", last_name: "Ailleurs", joined_via: "code", joined_at: 1.day.ago)

    sign_in_as kofi
    get school_admin_classrooms_path

    assert_response :success
    assert_select "#staff_arrivals[role=status].mb-6.rounded-ln.bg-school\\/10.px-4.py-3.text-sm.text-ink + #student_work"
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
