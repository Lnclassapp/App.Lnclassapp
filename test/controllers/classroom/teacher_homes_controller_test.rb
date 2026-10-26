require "test_helper"

# TR-05, TR-02 (UDR-0026): the teacher home. The old feed raised NameError as soon as the teacher had a classroom, a
# teacher without a school bounced between / and /teachers/classrooms, and a « Prepa » amount in FCFA sat on a dead block.
# RE-13, RE-16 to RE-18, RE-28 (UDR-0069): « Cours » (one bubble per level taught).
# Lot G (UDR enseignant §3.3, CA-G1 to CA-G9, CA-L1, CA-B8): band, class cards, week and history.
class Classroom::TeacherHomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @svt = create_material(name: "SVT", category: "science")
    @tle = create_level(name: "Tle")
    @classroom = create_classroom(school: @school, level: @tle, name: "Tle D 1")
    @teacher = create_teacher(school: @school, material: @svt, classrooms: [ @classroom ], first_name: "Yao")
  end

  # The table holds due_on 1 to 7 days after the day of assignment: assigned the day before its due date.
  def due(days) = { due_on: Date.current + days, assigned_at: (Date.current + days - 1).in_time_zone.change(hour: 12) }
  def tl(key, **) = I18n.t("classroom.teacher_homes.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def illustration(file) = ActionController::Base.helpers.image_path("subjects/#{file}.svg")
  def bubble_ids = css_select("#teacher_home_course_levels li a").map { it["id"] }

  # Koffi (RE-13): Maths in 3ème 1, 3ème 2, 1ère A and Tle D, and an archived 4ème.
  def maths_teacher
    third, fourth, first = { "3ème" => 4, "4ème" => 3, "1ère" => 6 }.map { |name, position| create_level(name:, position:) }
    classrooms = [ create_classroom(school: @school, level: @tle, series: create_series(name: "D"), name: "Tle D 2"),
                   create_classroom(school: @school, level: third, name: "3ème 2"),
                   create_classroom(school: @school, level: first, series: create_series(name: "A"), name: "1ère A 1"),
                   create_classroom(school: @school, level: third, name: "3ème 1"),
                   create_classroom(school: @school, level: fourth, name: "4ème 1", status: "archived") ]
    create_teacher(school: @school, material: create_material(name: "Mathématiques"), classrooms:)
  end

  # ADR-0103 §4.6: no list in the current school: the courses and the activities invite to choose, nothing reads « de , ».
  test "a teacher without any subject in the current school is invited to choose them in Courses and in the week" do
    Orm::TeacherSchoolMaterial.where(teacher_id: @teacher.id).delete_all
    sign_in_as @teacher

    get teacher_home_path

    assert_response :success
    [ "#teacher_home_courses_no_materials", "#teacher_home_week_no_materials" ].each do |id|
      assert_select id, text: including(tl("choose_materials.title"))
      assert_select "#{id} a[href='#{edit_profile_materials_path}'][data-turbo-frame=modal]"
    end
    assert_select "#teacher_home_course_levels", 0
  end

  test "CA-G2, CA-B8: the card of a classroom of 20, 2 active exercises: header, headcount, exercises, badges without zero, code and « Copier »" do
    @school.update!(sigle: "CSMT")
    exercises = Array.new(2) { create_exercise(essential: create_essential(course: create_course(material: @svt))) }
    assignments = exercises.map { create_assignment(classroom: @classroom, assignable: it, by: @teacher) }
    # 6 Bronze, 5 Argent, 3 Or, 1 Diamant, 5 Pas encore
    { 55 => 6, 70 => 5, 85 => 3, 100 => 1, 20 => 5 }.each do |percent, count|
      count.times do
        student = create_student(classroom: @classroom)
        create_exercise_session(student:, exercise: exercises.first, status: "completed", classroom_assignment: assignments.first,
                                score_percent: percent)
      end
    end
    code = Orm::Classroom.find(@classroom.id).join_code
    sign_in_as @teacher

    get teacher_home_path

    assert_response :success
    assert_select "#teacher_home_classrooms li#classroom_#{@classroom.public_id}" do
      assert_select "a[href='#{classroom_path(@classroom.public_id)}']", text: including("Tle D 1 · CSMT")
      assert_select "*", text: including(tl("classroom_card.students", count: 20))
      assert_select "*", text: including(tl("classroom_card.assignments", count: 2))
      assert_select "ul[aria-label] > li", 4
      assert_select "li", text: /Bronze\s*6/
      assert_select "li", text: /Argent\s*5/
      assert_select "li", text: /Or\s*3/
      assert_select "li", text: /Diamant\s*1/
      assert_select "li .sr-only", text: I18n.t("assessment.comprehension.badge_box", count: 6, level: "Bronze")
      assert_select "*", text: including("Pas encore"), count: 0
      assert_select "#classroom_code_#{@classroom.public_id}", text: including(Entities::Classroom::JoinCode.display(code))
      assert_select "[data-controller=clipboard][data-clipboard-text-value='#{Entities::Classroom::JoinCode.display(code)}']"
    end
  end

  test "CA-B8: a teacher of another classroom does not see this code" do
    other = create_teacher(school: @school, material: @svt, classrooms: [ create_classroom(school: @school, level: @tle, name: "Tle D 9") ])
    code = Entities::Classroom::JoinCode.display(Orm::Classroom.find(@classroom.id).join_code)
    sign_in_as other

    get teacher_home_path

    assert_not_includes response.body, code
  end

  test "an empty classroom, no assignment: « Aucun élève », the hint, no badge, the code stays" do
    sign_in_as @teacher

    get teacher_home_path

    assert_select "li#classroom_#{@classroom.public_id}" do
      assert_select "*", text: including(tl("classroom_card.students", count: 0))
      assert_select "*", text: including(tl("classroom_card.empty_hint"))
      assert_select "*", text: including(tl("classroom_card.assignments", count: 0)), count: 0
      assert_select "ul[aria-label='#{tl('classroom_card.badges_label')}']", 0
      assert_select "[data-controller=clipboard]", 1
    end
  end

  test "CA-G1: the band, the classrooms, the levels with « Inviter », the announcements, the week, the history; no greeting, no bottom bar" do
    create_message(author: create_team_member(second_factor: false), title: "Conseil de classe", audience: "teachers")
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise(essential: create_essential(course: create_course(material: @svt))),
                                   by: @teacher, **due(-1))
    student = create_student(classroom: @classroom)
    create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                            classroom_assignment: assignment, score_percent: 80)
    sign_in_as @teacher

    get teacher_home_path

    assert_select "header.teacher-band.bg-teacher"
    sections = "#teacher_home_classrooms, #teacher_home_courses, #student_home_announcements, #teacher_home_week, #teacher_home_history"
    assert_equal %w[teacher_home_classrooms teacher_home_courses student_home_announcements teacher_home_week teacher_home_history],
                 css_select(sections).map { it["id"] }
    assert_select "#teacher_home_week h2.sr-only", text: tl("follow_ups.title")
    assert_select "#teacher_home_history h2.sr-only", text: tl("history.title")
    assert_select "h1.sr-only"
    assert_no_match(/Bonjour, /, response.body)
    assert_select "nav.bottom-0", 0
  end

  test "CA-G4: the carousel ends with « + Ajouter une classe »" do
    second = create_classroom(school: @school, level: @tle, name: "Tle D 2")
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom: second)
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#teacher_home_classrooms.min-w-0 [data-controller='communication--carousel']" do
      assert_select "ul.overflow-x-auto.snap-x[data-communication--carousel-target=track][aria-label='Mes classes'] > li", 3 do |items|
        assert_equal [ "classroom_#{@classroom.public_id}", "classroom_#{second.public_id}", "add_classroom" ], items.map { it["id"] }
        items.each { assert_includes it["class"], "basis-5/6" }
      end
      assert_select "li#add_classroom a[href='#{teacher_classrooms_path}']", text: including(tl("add_classroom_card.action"))
      assert_select "[data-communication--carousel-target=pager][aria-hidden=true] [data-communication--carousel-target=dot]", 3
    end
    assert_select "#teacher-classrooms-menu", 0
  end

  test "CA-L1, CA-G4: without a classroom, the top card says « Ajoutez vos classes », a full-width primary button, and nothing else" do
    @school.update!(sigle: "CSMT")
    sign_in_as create_teacher(school: @school, material: @svt)

    get teacher_home_path

    assert_response :success
    assert_select "#teacher_home_classrooms li", 1
    assert_select "#teacher_home_classrooms li#add_classroom" do
      assert_select "*", text: including("CSMT")
      assert_select "*", text: including(tl("add_classroom_card.empty_title"))
      assert_select "*", text: including(tl("add_classroom_card.empty_description"))
      assert_select "a[href='#{teacher_classrooms_path}'].w-full", text: including(tl("add_classroom_card.action"))
    end
    assert_select "#teacher_home_week", text: including(tl("follow_ups.empty"))
    assert_select "#teacher_home_history", 0
  end

  test "CA-2: the announcements to teachers, read only — no cross to hide them" do
    create_message(author: create_team_member(second_factor: false), title: "Conseil de classe", audience: "teachers")
    create_message(author: create_team_member(second_factor: false), title: "Pour les élèves", audience: "students")
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#student_home_announcements li article h3", text: "Conseil de classe"
    assert_select "#student_home_announcements", text: including("Pour les élèves"), count: 0
    assert_select "#student_home_announcements form[action*='dismissal']", 0
  end

  test "CA-2: neither an announcement of another school, nor one to the direction, reaches the teacher's home" do
    team = create_team_member(second_factor: false)
    create_message(author: team, title: "Ailleurs", audience: "teachers", school: create_school)
    create_message(author: team, title: "Pour la direction", audience: "school_admins")
    create_message(author: team, title: "Chez nous", audience: "teachers", school: @school)
    sign_in_as @teacher

    get teacher_home_path

    assert_equal [ "Chez nous" ], css_select("#student_home_announcements li article h3").map { it.text.strip }
  end

  test "CA-2: without a readable announcement, no announcement section" do
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#student_home_announcements", 0
  end

  test "CA-G6: the week lists the exercise with « 20 / 27 faits » style progress and the pill « pas encore », to its follow-up" do
    students = Array.new(3) { create_student(classroom: @classroom) }
    exercise = create_exercise(title: "Photosynthèse", essential: create_essential(course: create_course(material: @svt)))
    assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, **due(3))
    create_exercise_session(student: students.first, exercise:, status: "completed", classroom_assignment: assignment)
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#teacher_home_week li#follow_up_#{assignment.public_id}" do
      assert_select "a[href='#{classroom_assignment_path(@classroom.public_id, assignment.public_id)}']", text: "Photosynthèse"
      assert_select "*", text: including("Tle D 1")
      assert_select "*", text: including(tl("follow_ups.done", done: 1, count: 3))
      assert_select "[role=progressbar][aria-valuenow='1'][aria-valuemax='3'] span.bg-teacher"
      assert_select "*", text: including(tl("follow_ups.pending", count: 2))
      assert_select "*", text: including(tl("follow_ups.late", count: 2)), count: 0
    end
  end

  test "CA-G6: the same exercise, due two days ago, reads « en retard » and never « pas encore »" do
    create_student(classroom: @classroom)
    exercise = create_exercise(essential: create_essential(course: create_course(material: @svt)))
    assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, **due(-2))
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#teacher_home_week li#follow_up_#{assignment.public_id}" do
      assert_select "*", text: including(tl("follow_ups.late", count: 1))
      assert_select "*", text: including(tl("follow_ups.pending", count: 1)), count: 0
    end
    assert_select "#teacher_home_history", 0
  end

  test "CA-3: nothing to follow — the empty state, and no history section" do
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#teacher_home_week", text: including(tl("follow_ups.empty"))
    assert_select "#teacher_home_week li", 0
    assert_select "#teacher_home_history", 0
  end

  test "CA-G7: the history groups done exercises by due day, with the class average, and shares nothing with the week" do
    student = create_student(classroom: @classroom)
    exercise = create_exercise(title: "Respiration", essential: create_essential(course: create_course(material: @svt)))
    done = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, **due(-1))
    create_exercise_session(student:, exercise:, status: "completed", classroom_assignment: done, score_percent: 90)
    old = create_assignment(classroom: @classroom, assignable: create_exercise(title: "Ancien", essential: create_essential(course: create_course(material: @svt))),
                            by: @teacher, **due(-20))
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#teacher_home_history li#history_#{done.public_id}" do
      assert_select "a[href='#{classroom_assignment_path(@classroom.public_id, done.public_id)}']", text: "Respiration"
      assert_select "*", text: including(tl("history.yesterday"))
      assert_select "*", text: including(tl("follow_ups.done", done: 1, count: 1))
      assert_select ".text-success", text: tl("history.average", grade: "18")
    end
    assert_select "#teacher_home_history li#history_#{old.public_id}"
    assert_select "#teacher_home_week li#follow_up_#{old.public_id}", 0
    assert_select "#teacher_home_week li#follow_up_#{done.public_id}", 0
  end

  test "CA-G8: four exercises in the week, or in the history — three shown, the fourth behind « Voir plus »" do
    create_student(classroom: @classroom)
    4.times do |index|
      upcoming, old = Array.new(2) { create_exercise(essential: create_essential(course: create_course(material: @svt))) }
      create_assignment(classroom: @classroom, assignable: upcoming, by: @teacher, **due(index + 1))
      create_assignment(classroom: @classroom, assignable: old, by: @teacher, **due(-15 - index))
    end
    sign_in_as @teacher

    get teacher_home_path

    %w[week history].each do |section|
      assert_select "#teacher_home_#{section}[data-controller=reveal]" do
        assert_select "li[data-reveal-target=item]", 4
        assert_select "li[data-reveal-target=item][hidden]", 1
        assert_select "button[data-reveal-target=button]", text: including("Voir plus")
      end
    end
  end

  test "CA-G9: no view writes bg-teacher by hand; the band takes it from the role helper" do
    sign_in_as @teacher

    get teacher_home_path

    assert_empty Dir["#{Rails.root}/app/views/classroom/teacher_homes/*"].select { File.read(it).include?("bg-teacher") }
    assert_select "header.teacher-band.bg-teacher"
  end

  test "RE-13: one bubble per level and series taught, in order, with the Maths drawing, then « Inviter »" do
    sign_in_as maths_teacher

    get teacher_home_path

    assert_select "nav#teacher_home_course_levels[aria-label='Vos niveaux et actions'] > ul.grid.grid-cols-4"
    assert_equal %w[course_level_3eme course_level_1ere_a course_level_tle_d course_level_invite], bubble_ids
    { "3eme" => [ "3ème", courses_path(level: "3eme", material: "mathematiques") ],
      "1ere_a" => [ "1ère A", courses_path(level: "1ere", series: "a", material: "mathematiques") ],
      "tle_d" => [ "Tle D", courses_path(level: "tle", series: "d", material: "mathematiques") ] }.each do |key, (label, href)|
      assert_select "a#course_level_#{key}[href='#{href}']", text: including(label) do
        assert_select "img[src='#{illustration('maths')}'][alt='']"
        assert_select ".sr-only", text: ", fiches de cours de Mathématiques"
      end
    end
    assert_select "a#course_level_invite", text: including("Inviter") do
      assert_select "img[src='#{illustration('inviter')}']"
    end
    assert_select "#teacher_home_course_levels", text: including("4ème"), count: 0
    assert_select "#teacher_home_courses_empty", 0
    assert_select "a#teacher_home_courses", 0
  end

  test "IE-20: « Inviter » opens WhatsApp in a new tab with the invitation message and its /i/<token> link, the share counted" do
    sign_in_as @teacher

    get teacher_home_path

    link = teacher_invite_link_url(Orm::TeacherSchool.find_by!(teacher: @teacher).invite_token)
    message = I18n.t("identity.referrals.invite.message", school: "Lycée Classique d'Abidjan", link:)
    assert_match %r{/i/\h{12}\z}, link
    assert_select "#teacher_home_course_levels li[data-controller='identity--share']" \
                  "[data-identity--share-url-value='#{teacher_referral_shares_path}'][data-identity--share-link-value='#{link}']" \
                  "[data-identity--share-text-value=?]", message do
      assert_select "a#course_level_invite[href=?][target=_blank][rel=noopener]" \
                    "[data-action='identity--share#record'][data-identity--share-channel-param=whatsapp]",
                    "https://wa.me/?text=#{ERB::Util.url_encode(message)}" do
        assert_select "span", text: "Inviter"
        assert_select ".sr-only", text: "sur WhatsApp"
      end
    end
    # The « Inviter un collègue » page stays reachable by its own address and by the sidebar card.
    assert_select "#sidebar_referral a[href='#{teacher_invite_path}']"
    get teacher_invite_path
    assert_response :success
  end

  test "RE-16: a teacher without a classroom this year has no level bubble, a hint, « Inviter » and the full catalog" do
    sign_in_as create_teacher(school: @school, material: @svt)

    get teacher_home_path

    assert_select "#teacher_home_courses_empty", text: "Déclarez vos classes pour retrouver ici les fiches de cours de vos niveaux."
    assert_equal %w[course_level_invite], bubble_ids
  end

  test "RE-17: a subject without a drawing of its own gets the generic one" do
    english = create_material(name: "Anglais", category: "literature")
    sign_in_as create_teacher(school: @school, material: english, classrooms: [ @classroom ])

    get teacher_home_path

    assert_select "a#course_level_tle[href='#{courses_path(level: 'tle', material: english.slug)}']" do
      assert_select "img[src='#{illustration('generique')}']"
      assert_select ".sr-only", text: ", fiches de cours de Anglais"
    end
  end

  # EPM-13, EPM-16 (UDR-0126 §3.2 to §3.4) : deux badges, des bulles génériques vers toutes ses matières, un badge par activité.
  test "EPM-13: a teacher of two subjects reads both badges, generic bubbles to all his subjects, a badge on each activity" do
    pc = create_material(name: "Physique-Chimie", category: "science")
    teacher = create_teacher(school: @school, materials: [ pc, @svt ], classrooms: [ @classroom ])
    create_student(classroom: @classroom)
    exercise = create_exercise(essential: create_essential(course: create_course(material: pc, level: @tle)))
    create_assignment(classroom: @classroom, assignable: exercise, by: teacher, **due(1))
    sign_in_as teacher

    get teacher_home_path

    assert_select "a#course_level_tle[href='#{courses_path(level: 'tle')}']" do
      assert_select "img[src='#{illustration('generique')}']"
      assert_select ".sr-only", text: ", fiches de cours de vos matières"
    end
    assert_select "#teacher_home_week li", text: /Physique-Chimie/
  end

  test "RE-18: a teacher whose primary school is inactive sees neither the « Inviter » bubble nor the invitation block" do
    @school.update!(status: "inactive")
    sign_in_as @teacher

    get teacher_home_path

    assert_response :success
    assert_equal %w[course_level_tle], bubble_ids
    assert_select "#course_level_invite", 0
    assert_select "#invite_colleagues", 0
  end

  # UDR enseignant §3.3: the « Inviter un collègue » card under lg is gone; the « Inviter » bubble and the sidebar card remain.
  test "RE-20: no invitation block in the page body any more" do
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#main #invite_colleagues", 0
  end

  test "RE-28, TR-06 dropped: no « Versement », no « Prepa » amount nor FCFA" do
    sign_in_as maths_teacher

    get teacher_home_path

    # « Téléversement » is not a « Versement »: the word alone.
    assert_no_match(/(?<![[:alpha:]])versement|prepa|fcfa/i, response.body)
  end

  test "a teacher whose setup is not finished lands on the home, which asks for their classrooms (UDR §3.13)" do
    sign_in_as create_teacher(school: @school, onboarded: false)

    get teacher_home_path

    assert_response :success
    assert_select "#teacher_home_classrooms li#add_classroom"
  end

  test "a teacher without a primary school: one redirection, to the exit screen, which answers" do
    teacher = create_teacher(school: @school)
    Orm::TeacherSchool.where(teacher:).delete_all
    sign_in_as teacher

    get teacher_home_path

    assert_redirected_to pending_account_path
    follow_redirect!
    assert_response :success
  end

  test "a student and the team receive 403" do
    [ create_student(classroom: @classroom), create_team_member ].each do |user|
      sign_in_as user

      get teacher_home_path

      assert_response :forbidden
      sign_out
    end
  end
end
