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

  # accueil-enseignant-actions (UDR §3.1, CA-1) : « À suivre » d'abord, la plus urgente en tête ; les autres classes repliées.
  test "CA-1: « À suivre » lists the late classroom first, then the busy one, each a link; the quiet one is folded below" do
    first = create_level(name: "1ère", position: 6)
    busy = create_classroom(school: @school, level: first, series: create_series(name: "D"), name: "1ère D")
    sixth = create_classroom(school: @school, level: create_level(name: "6ème", position: 1), name: "6ème 1")
    [ busy, sixth ].each { Orm::TeacherClassroom.create!(teacher: @teacher, classroom: it) }
    students = Array.new(3) { create_student(classroom: @classroom) }
    create_student(classroom: busy)
    create_student(classroom: sixth)
    exercise = create_exercise(essential: create_essential(course: create_course(material: @svt)))
    late = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, **due(-1))
    create_exercise_session(student: students.first, exercise:, status: "completed", classroom_assignment: late)
    2.times { create_assignment(classroom: busy, assignable: create_exercise, by: @teacher, **due(2)) }
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#teacher_home_classrooms h2#teacher_home_classrooms_title", text: tl("to_follow.title")
    assert_select "ul#teacher_home_to_follow > li", 2 do |items|
      assert_equal [ "classroom_#{@classroom.public_id}", "classroom_#{busy.public_id}" ], items.map { it["id"] }
    end
    assert_select "ul#teacher_home_to_follow li#classroom_#{@classroom.public_id}" do
      assert_select "a[href='#{classroom_path(@classroom.public_id)}']", text: "Tle D 1"
      assert_select "p.text-warning", text: "2 élèves en retard sur 1 exercice"
    end
    assert_select "ul#teacher_home_to_follow li#classroom_#{busy.public_id}", text: including("2 exercices en cours")
    assert_select "ul#teacher_home_to_follow li#classroom_#{sixth.public_id}", 0
    assert_select "details#teacher_home_other_classrooms" do
      assert_select "summary", text: including("Voir mon autre classe")
      assert_select "li#classroom_#{sixth.public_id} a[href='#{classroom_path(sixth.public_id)}']", text: "6ème 1"
      assert_select "li#classroom_#{sixth.public_id}", text: including("1 élève")
      assert_select "li#add_classroom a[href='#{teacher_classrooms_path}']", text: tl("add_classroom_card.action")
    end
    assert_select "[data-controller='communication--carousel']", 0
    assert_select "#teacher_home_to_follow", text: including("Copier"), count: 0
  end

  test "CA-1: every classroom to follow — no folded classrooms, « + Ajouter une classe » ends the list" do
    create_student(classroom: @classroom)
    create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher, **due(1))
    sign_in_as @teacher

    get teacher_home_path

    assert_select "ul#teacher_home_to_follow > li", 2
    assert_select "ul#teacher_home_to_follow > li:last-child#add_classroom"
    assert_select "#teacher_home_other_classrooms", 0
  end

  # UDR §3.1, CA-2 : rien à suivre, jamais de section vide : « Mes classes », trois, puis les suivantes repliées.
  test "CA-2: nothing to follow — « Mes classes », three classrooms, then « Voir mes N autres classes »" do
    4.times { |index| Orm::TeacherClassroom.create!(teacher: @teacher, classroom: create_classroom(school: @school, level: @tle, name: "Tle D #{index + 2}")) }
    create_student(classroom: @classroom)
    sign_in_as @teacher

    get teacher_home_path

    assert_select "h2#teacher_home_classrooms_title", text: tl("to_follow.title_all")
    assert_select "ul#teacher_home_to_follow > li", 3
    assert_select "ul#teacher_home_to_follow li#classroom_#{@classroom.public_id}", text: including("1 élève")
    assert_select "details#teacher_home_other_classrooms summary", text: including("Voir mes 2 autres classes")
    assert_select "details#teacher_home_other_classrooms li", 3
  end

  test "an empty classroom with an assignment is never to follow: « Aucun élève »" do
    create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher, **due(-1))
    sign_in_as @teacher

    get teacher_home_path

    assert_select "h2#teacher_home_classrooms_title", text: tl("to_follow.title_all")
    assert_select "li#classroom_#{@classroom.public_id}", text: including("Aucun élève")
  end

  test "CA-G1: the band, the classrooms, the levels with « Inviter », the announcements, the week, the history; no greeting, no bottom bar" do
    create_message(author: create_team_member(second_factor: false), title: "Conseil de classe", audience: "teachers")
    exercise = create_exercise(essential: create_essential(course: create_course(material: @svt)))
    assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, **due(-1))
    create_assignment(classroom: @classroom, assignable: create_exercise(essential: create_essential(course: create_course(material: @svt))),
                      by: @teacher, **due(2))
    student = create_student(classroom: @classroom)
    create_exercise_session(student:, exercise:, status: "completed", classroom_assignment: assignment, score_percent: 80)
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
    # Ce que l'enseignant voit : la seule « Navigation principale » est celle de la barre latérale ; aucune barre basse ni « Plus ».
    navigation = I18n.t("shared.navigation.bottom_bar.label")
    assert_select "nav[aria-label=?]", navigation, 1
    assert_select "aside nav[aria-label=?]", navigation, 1
    assert_select "button", text: I18n.t("shared.navigation.bottom_bar.more"), count: 0
  end

  test "CA-L1, CA-3: without a classroom, the card says « Ajoutez vos classes », a full-width primary button, and no list" do
    @school.update!(sigle: "CSMT")
    sign_in_as create_teacher(school: @school, material: @svt)

    get teacher_home_path

    assert_response :success
    assert_select "#teacher_home_to_follow", 0
    assert_select "#teacher_home_classrooms div#add_classroom" do
      assert_select "*", text: including("CSMT")
      assert_select "*", text: including(tl("add_classroom_card.empty_title"))
      assert_select "*", text: including(tl("add_classroom_card.empty_description"))
      assert_select "a[href='#{teacher_classrooms_path}'].w-full", text: including(tl("add_classroom_card.action"))
    end
    assert_select "#teacher_home_week", 0
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
    assert_select "#student_home_announcements a[href=?]", announcements_path, 0
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

  # UDR accueil-enseignant-actions §3.3, CA-5 : jamais de section vide.
  test "CA-5: no exercise this week — no « Cette semaine » section at all, and no history section" do
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#teacher_home_week", 0
    assert_no_match(/Aucun exercice à suivre/, response.body)
    assert_select "#teacher_home_history", 0
  end

  test "CA-G7: the history groups done exercises by due day, with the class average, and shares nothing with the week" do
    student = create_student(classroom: @classroom)
    exercise = create_exercise(title: "Respiration", essential: create_essential(course: create_course(material: @svt)))
    done = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, **due(-1))
    record_medal(create_exercise_session(student:, exercise:, status: "completed", classroom_assignment: done, score_percent: 90))
    old = create_assignment(classroom: @classroom, assignable: create_exercise(title: "Ancien", essential: create_essential(course: create_course(material: @svt))),
                            by: @teacher, **due(-20))
    sign_in_as @teacher

    get teacher_home_path

    assert_select "#teacher_home_history li#history_#{done.public_id}" do
      assert_select "a[href='#{classroom_assignment_path(@classroom.public_id, done.public_id)}']", text: "Respiration"
      assert_select "*", text: including(tl("history.yesterday"))
      assert_select "*", text: including(tl("follow_ups.done", done: 1, count: 1))
      assert_select "ul[aria-label=?]", tl("history.medals_label"), text: /Or\s+1/
      assert_select "*", text: %r{/20|Moyenne}, count: 0
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

  # RE-13 ; accueil-enseignant-actions (UDR §3.2, CA-4) : un titre visible, le nom court du niveau dans le rond, une teinte par rond.
  test "RE-13, CA-4: « Fiches de cours · Mathématiques », one bubble per level and series taught, in order, its short name on its own tint" do
    sign_in_as maths_teacher

    get teacher_home_path

    assert_select "h2#teacher_home_courses_title:not(.sr-only)", text: "Fiches de cours · Mathématiques"
    assert_select "nav#teacher_home_course_levels[aria-label='Vos niveaux et actions'] > ul.grid.grid-cols-4"
    assert_equal %w[course_level_3eme course_level_1ere_a course_level_tle_d course_level_invite], bubble_ids
    { "3eme" => [ "3ème", "3e", "bg-tint-indigo", courses_path(level: "3eme", material: "mathematiques") ],
      "1ere_a" => [ "1ère A", "1re A", "bg-tint-green", courses_path(level: "1ere", series: "a", material: "mathematiques") ],
      "tle_d" => [ "Tle D", "Tle D", "bg-tint-yellow", courses_path(level: "tle", series: "d", material: "mathematiques") ] }
      .each do |key, (label, short, tint, href)|
      assert_select "a#course_level_#{key}[href='#{href}'][title='#{label}']" do
        assert_select "span.#{tint} span[aria-hidden=true]", text: short
        assert_select "img", 0
        assert_select ".sr-only", text: label
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
    # The « Inviter un collègue » page stays reachable by its own address; the sidebar no longer has a card for it (lot P0).
    assert_select "aside", text: /Parrainage/, count: 0
    get teacher_invite_path
    assert_response :success
  end

  test "RE-16: a teacher without a classroom this year has no level bubble, a hint, « Inviter » and the full catalog" do
    sign_in_as create_teacher(school: @school, material: @svt)

    get teacher_home_path

    assert_select "#teacher_home_courses_empty", text: "Déclarez vos classes pour retrouver ici les fiches de cours de vos niveaux."
    assert_equal %w[course_level_invite], bubble_ids
  end

  test "RE-17: a subject without a drawing of its own: the bubble carries the level, the title names the subject" do
    english = create_material(name: "Anglais", category: "literature")
    sign_in_as create_teacher(school: @school, material: english, classrooms: [ @classroom ])

    get teacher_home_path

    assert_select "h2#teacher_home_courses_title", text: "Fiches de cours · Anglais"
    assert_select "a#course_level_tle[href='#{courses_path(level: 'tle', material: english.slug)}']" do
      assert_select "span[aria-hidden=true]", text: "Tle"
      assert_select ".sr-only", text: ", fiches de cours de Anglais"
    end
  end

  # EPM-13, EPM-16 (UDR-0126 §3.2 to §3.4) : deux badges, des bulles génériques vers toutes ses matières, un badge par activité.
  test "EPM-13: a teacher of two subjects reads both badges, bubbles to all his subjects, a badge on each activity" do
    pc = create_material(name: "Physique-Chimie", category: "science")
    teacher = create_teacher(school: @school, materials: [ pc, @svt ], classrooms: [ @classroom ])
    create_student(classroom: @classroom)
    exercise = create_exercise(essential: create_essential(course: create_course(material: pc, level: @tle)))
    create_assignment(classroom: @classroom, assignable: exercise, by: teacher, **due(1))
    sign_in_as teacher

    get teacher_home_path

    assert_select "h2#teacher_home_courses_title", text: "Fiches de cours"
    assert_select "a#course_level_tle[href='#{courses_path(level: 'tle')}']" do
      assert_select "img", 0
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
    assert_select "#teacher_home_classrooms #add_classroom"
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

  test "a teacher whose current school is not primary and who has no primary school is sent to the exit screen" do
    other = create_school(name: "Collège Saint-Michel")
    teacher = create_teacher(school: @school)
    Orm::TeacherSchool.create!(teacher:, school: other, primary: false)
    sign_in_as teacher
    patch teacher_current_school_path, params: { school_public_id: other.public_id }
    Orm::TeacherSchool.where(teacher:, school: @school).delete_all

    get teacher_home_path

    assert_redirected_to pending_account_path
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
