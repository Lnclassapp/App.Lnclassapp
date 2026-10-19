require "test_helper"

# CL-12, AS-20, UDR-0029: the teacher opens an essential sheet from their classroom and sees its published exercises,
# each one « Assigné » or « Assigner », with the classroom's success rate. Since ADR-0072 the sheet itself is no longer
# assigned (UDR-0029, amended 2026-10-02): its header has no toggle. The old screen raised PG::UndefinedColumn as soon as
# the sheet had an exercise.
class Classroom::ClassroomEssentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Le cours est celui que la page de la classe affiche pour son enseignant : même niveau, même matière (ADR-0101 §4.4).
    @level = create_level
    @material = create_material
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"), level: @level)
    @teacher = create_teacher(classrooms: [ @classroom ], material: @material)
    @course = create_course(name: "Génétique et évolution", level: @level, material: @material)
    @essential = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions")
    @phases = create_exercise(essential: @essential, title: "Les phases", questions: 3)
    @brassage = create_exercise(essential: @essential, title: "Le brassage", questions: 1)
  end

  def tl(key, **) = I18n.t("classroom.classroom_essentials.show.#{key}", **)
  def toggle(key) = I18n.t("classroom.assignments.toggle.#{key}")
  def including(text) = /#{Regexp.escape(text)}/
  def toggle_id(type, key) = "#assignment_#{@classroom.public_id}_#{type}_#{key}"
  def page_path(classroom = @classroom, essential = @essential) = classroom_essential_path(classroom.public_id, @course.slug, essential.slug)

  test "the teacher sees the sheet, its published exercises, their assignment state and the classroom success rate" do
    create_exercise(essential: @essential, title: "Brouillon", status: "draft")
    assignment = create_assignment(classroom: @classroom, assignable: @phases, by: @teacher)
    student = create_student(classroom: @classroom)
    create_exercise_session(student:, exercise: @phases, status: "completed", score_percent: 72)
    sign_in_as @teacher

    get page_path

    assert_response :success
    assert_select "h1", text: "La méiose"
    assert_select "a[href='#{classroom_course_path(@classroom.public_id, @course.slug)}']", text: including("Génétique et évolution")
    assert_select "*", text: including(tl("context", classroom: "Tle D 1", school: "Lycée Classique"))
    assert_select "[id^='assignment_#{@classroom.public_id}_Essential']", 0
    assert_select "#classroom_essential_exercises li", 2
    assert_select "#classroom_essential_exercises li", text: /Brouillon/, count: 0
    assert_select toggle_id("Exercise", @phases.public_id) do
      assert_select "*", text: including(toggle(:assigned))
      assert_select "form[action='#{archive_assignment_path(assignment.public_id)}']"
    end
    assert_select toggle_id("Exercise", @brassage.public_id), text: including(toggle(:assign))
    assert_select "#classroom_essential_exercises", text: including(tl("questions", count: 3))
    assert_select "#classroom_essential_exercises", text: including(tl("success_rate", percent: 100, passed: 1, count: 1))
    assert_select "#classroom_essential_exercises", text: including(tl("no_result"))
  end

  # ADR-0072, UDR-0029 (amendée le 2026-10-02) : la bascule de la fiche et son role="group" disparaissent de l'en-tête.
  test "the header of the sheet has no toggle nor group, only the exercises carry one" do
    # Jours renseignés : les bascules sont des formulaires (sans eux, des liens vers la modale des jours, UDR-0062 §3.4).
    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1 ],
                                                                at: Time.current)
    sign_in_as @teacher

    get page_path

    assert_response :success
    assert_select "[role=group]", 0
    assert_select "form[action='#{classroom_assignments_path(@classroom.public_id)}'] input[name='assignment[assignable_type]']" do |inputs|
      assert_equal [ "Exercise" ], inputs.map { it["value"] }.uniq
    end
  end

  test "a sheet without published exercise shows the empty state" do
    essential = create_essential(course: @course)
    sign_in_as @teacher

    get page_path(@classroom, essential)

    assert_response :success
    assert_select "#classroom_essential_exercises", text: including(tl("empty"))
  end

  # vie-de-la-classe, Lot C (Q8) : une classe archivée n'a plus de page, même pour son enseignant (était : états sans bascule).
  test "an archived classroom: 404 for its teacher" do
    archived = create_classroom(status: "archived")
    teacher = create_teacher(classrooms: [ archived ])
    create_assignment(classroom: archived, assignable: @phases, by: teacher)
    sign_in_as teacher

    get page_path(archived)

    assert_response :not_found
    assert_select "#classroom_essential_exercises", 0
  end

  test "the team reads the page with its toggles" do
    sign_in_as create_team_member

    get page_path

    assert_response :success
    assert_select toggle_id("Exercise", @phases.public_id)
  end

  test "another teacher or a student of the classroom receives 403, without the sheet" do
    [ create_teacher, create_student(classroom: @classroom) ].each do |user|
      sign_in_as user

      get page_path

      assert_response :forbidden
      assert_no_match "La méiose", response.body
      sign_out
    end
  end

  test "an unknown classroom, an unknown or unpublished sheet: 404" do
    draft = create_essential(course: @course, status: "draft")
    sign_in_as @teacher

    get classroom_essential_path("inconnue", @course.slug, @essential.slug)
    assert_response :not_found
    [ "inconnue", draft.slug ].each do |slug|
      get classroom_essential_path(@classroom.public_id, @course.slug, slug)
      assert_response :not_found
    end
  end

  # UDR-0062 §3.4 : sans jours de séance, « Assigner » est un lien vers la modale des jours, dans le frame « modal ».
  test "a teacher without session days: « Assigner » links to the days modal; with days, it posts directly" do
    sign_in_as @teacher

    get page_path

    assert_select toggle_id("Exercise", @phases.public_id) do
      assert_select "a[href='#{new_classroom_assignment_path(@classroom.public_id, assignable_key: @phases.public_id)}'][data-turbo-frame=modal]",
                    text: including(toggle(:assign))
      assert_select "form", 0
    end

    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1, 4 ],
                                                                at: Time.current)
    get page_path

    assert_select toggle_id("Exercise", @phases.public_id) do
      assert_select "form[action='#{classroom_assignments_path(@classroom.public_id)}']"
      assert_select "a[data-turbo-frame=modal]", 0
    end
  end

  # UDR-0069 §3.8 : la bascule nomme la classe dès le premier rendu, comme après un stream (et comme au catalogue).
  test "the toggle's accessible name names the exercise and the classroom" do
    sign_in_as @teacher

    get page_path

    label = I18n.t("classroom.assignments.toggle.assign_to_label", name: "Les phases", classroom: "Tle D 1")
    assert_select "#{toggle_id("Exercise", @phases.public_id)} [aria-label='#{label}']"
  end

  test "the team never gets the days modal" do
    sign_in_as create_team_member

    get page_path

    assert_select "a[href^='#{new_classroom_assignment_path(@classroom.public_id)}']", 0
    assert_select "#{toggle_id('Exercise', @phases.public_id)} form[action='#{classroom_assignments_path(@classroom.public_id)}']"
  end

  test "an assigned exercise shows its due date for the teacher, only when it has one" do
    create_assignment(classroom: @classroom, assignable: @phases, by: @teacher, due_on: Date.new(2026, 10, 8),
                      assigned_at: Time.zone.local(2026, 10, 5, 10))
    create_assignment(classroom: @classroom, assignable: @brassage, by: @teacher)
    sign_in_as @teacher

    get page_path

    assert_select toggle_id("Exercise", @phases.public_id), text: including("Pour jeu. 8 oct.")
    assert_select toggle_id("Exercise", @brassage.public_id), text: including("Sans date limite"), count: 0
  end

  # AS-17, UDR-0121 §3.2, ADR-0101 §4.4 : qui est à revoir sur la fiche, et qui l'a levée cette année.
  def gaps_tl(key, **) = I18n.t("classroom.classroom_essentials.gaps.#{key}", **)

  def gap(student, status: "pending", **attributes)
    source_session = create_exercise_session(student:, exercise: @phases, status: "completed", score_percent: 30)
    create_gap(student:, essential: @essential, status:, source_session:, **attributes)
  end

  def thales_class
    awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    bintou = create_student(classroom: @classroom, first_name: "Bintou", last_name: "Diallo")
    yao = create_student(classroom: @classroom, first_name: "Yao", last_name: "Kouassi")
    gap(awa, created_at: Time.zone.local(2026, 10, 12, 8), failed_sessions_count: 3)
    gap(bintou, created_at: Time.zone.local(2026, 10, 13, 8))
    gap(yao, status: "self_corrected", resolved_at: Time.zone.local(2026, 10, 14, 9))
    [ awa, bintou, yao ]
  end

  # « 2 sessions sous la moyenne » (pluriel dès 2) et une levée par remédiation, en plus de celle faite seul.
  def thales_class_with_two_failures_and_a_remediation
    kofi = create_student(classroom: @classroom, first_name: "Kofi", last_name: "Traoré")
    zoe = create_student(classroom: @classroom, first_name: "Zoé", last_name: "Koné")
    gap(kofi, created_at: Time.zone.local(2026, 10, 14, 8), failed_sessions_count: 2)
    gap(zoe, status: "remediated", resolved_at: Time.zone.local(2026, 10, 15, 9))
    [ kofi, zoe ]
  end

  test "the teacher reads the students to review, oldest first, then those who lifted the sheet, above the exercises" do
    travel_to Time.zone.local(2026, 10, 16, 10)
    @classroom.update!(school_year: "2026-2027")
    students = thales_class + thales_class_with_two_failures_and_a_remediation
    sign_in_as @teacher

    get page_path

    assert_response :success
    assert_select "#classroom_essential_gaps h2", text: gaps_tl("title")
    assert_select "#classroom_essential_gaps_pending" do
      assert_select "h2, h3", text: gaps_tl("pending_title")
      assert_select "li", 3
      assert_select "li:nth-child(1)", text: /Awa Bamba.*depuis le 12 oct\..*3 sessions sous la moyenne/m
      assert_select "li:nth-child(2)", text: /Bintou Diallo.*depuis le 13 oct\./m
      assert_select "li:nth-child(2)", text: /sous la moyenne/, count: 0
      assert_select "li:nth-child(3)", text: /Kofi Traoré.*2 sessions sous la moyenne/m
    end
    assert_select "#classroom_essential_gaps_lifted h3, #classroom_essential_gaps_lifted h2", text: "Fiche de révision levée"
    assert_select "#classroom_essential_gaps_lifted li", 2
    assert_select "#classroom_essential_gaps_lifted li", text: /Yao Kouassi.*le 14 oct\./m
    assert_select "#classroom_essential_gaps_lifted li", text: /Zoé Koné.*le 15 oct\./m
    assert_select "#classroom_essential_gaps", text: /remédiation|seul/i, count: 0
    assert_match(/id="classroom_essential_gaps".*id="classroom_essential_exercises"/m, response.body)
    students.each { assert_no_match(/#{it.public_id}/, response.body) }
  end

  test "only lifts: the lifted card alone; no gap: no section" do
    sign_in_as create_team_member

    get page_path

    assert_select "#classroom_essential_gaps", 0

    gap(create_student(classroom: @classroom), status: "remediated", resolved_at: Time.current)
    get page_path

    assert_select "#classroom_essential_gaps_lifted"
    assert_select "#classroom_essential_gaps_pending", 0
  end

  test "another teacher, the school staff and a student of the classroom never read a name" do
    awa, = thales_class
    intruders = [ create_teacher(classrooms: [ create_classroom ]), create_school_admin(school: @classroom.school), awa ]

    intruders.each do |intruder|
      sign_in_as intruder

      # Aucune requête ne touche knowledge_gaps : la liste nominative n'est même pas lue (ADR-0101 §4.4).
      statements = []
      callback = ->(*, payload) { statements << payload[:sql] if payload[:sql].include?("knowledge_gaps") }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get page_path }

      assert_response :forbidden
      assert_empty statements
      sign_out
    end
  end

  # Année scolaire de la classe (ADR-0041) : la page la passe à la requête, à l'heure d'Abidjan.
  test "only the lifts of the classroom's school year are listed" do
    travel_to Time.zone.local(2026, 10, 16, 10)
    @classroom.update!(school_year: "2025-2026")
    gap(create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba"), status: "self_corrected",
        resolved_at: Time.zone.local(2026, 3, 10, 9))
    gap(create_student(classroom: @classroom, first_name: "Yao", last_name: "Kouassi"), status: "self_corrected",
        resolved_at: Time.zone.local(2026, 10, 12, 9))
    sign_in_as @teacher

    get page_path

    assert_select "#classroom_essential_gaps_lifted li", 1
    assert_select "#classroom_essential_gaps_lifted", text: /Awa Bamba/
    assert_select "#classroom_essential_gaps_lifted", text: /Yao Kouassi/, count: 0
  end

  # ADR-0101 §4.4 : le bloc ne vaut que pour les cours que la page de la classe affiche (niveau, série, matière de
  # l'enseignant ; toute matière pour l'équipe). La fiche d'un autre cours reste lisible, sans le bloc.
  def pending_gap_on_sheet_of(course)
    sheet = create_essential(course:, name: "Fiche hors page")
    student = create_student(classroom: @classroom, first_name: "Fanta", last_name: "Sylla")
    create_gap(student:, essential: sheet,
               source_session: create_exercise_session(student:, exercise: create_exercise(essential: sheet), status: "completed",
                                                       score_percent: 30))
    classroom_essential_path(@classroom.public_id, course.slug, sheet.slug)
  end

  test "another subject: no gap block nor name for the teacher of the classroom, the team reads it" do
    path = pending_gap_on_sheet_of(create_course(level: @level, material: create_material(name: "Français")))
    sign_in_as @teacher

    get path

    assert_response :success
    assert_select "h1", text: "Fiche hors page"
    assert_select "#classroom_essential_gaps", 0
    assert_no_match(/Fanta Sylla/, response.body)
    sign_out

    sign_in_as create_team_member
    get path

    assert_select "#classroom_essential_gaps_pending", text: /Fanta Sylla/
  end

  test "another level or another series: no gap block, for the teacher as for the team" do
    series = create_series
    [ create_course(level: create_level, material: @material), create_course(level: @level, material: @material, series:) ].each do |course|
      path = pending_gap_on_sheet_of(course)

      [ @teacher, create_team_member ].each do |reader|
        sign_in_as reader

        get path

        assert_response :success
        assert_select "#classroom_essential_gaps", 0
        assert_no_match(/Fanta Sylla/, response.body)
        sign_out
      end
    end
  end
end
