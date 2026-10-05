require "test_helper"

# AD-09 to AD-12, AD-22 (UDR-0074 §3.8, §3.12): the page of a level shows a card per active classroom of the year of that
# level in the school of the direction, with the drawing of the level, the dot of its submission rate and its figures.
# Another school's, archived or past classrooms never show; a level without classroom is a 404, any other role a 403.
class SchoolAdmin::LevelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Collège Moderne de Bouaké")
    @admin = create_school_admin(school: @school)
    @level = create_level(name: "3ème", position: 4)
    @teacher = create_teacher(school: @school)
  end

  def tl(key, **) = I18n.t("school_admin.levels.#{key}", **)
  def signal_text(signal, key) = I18n.t("school_admin.signals.#{signal}.#{key}")
  def not_computed = I18n.t("school_admin.classrooms.not_computed")
  def card(classroom) = "li#classroom_#{classroom.public_id}"

  def classroom(name, school: @school, level: @level, **) = create_classroom(school:, level:, name:, **)

  # `students` present students and `assignments` given; the first students hand in the first assignment, one per score.
  def classroom_with(name, students:, assignments: 0, scores: [], **)
    klass = classroom(name, **)
    given = Array.new(assignments) { create_assignment(classroom: klass, by: @teacher) }
    pupils = Array.new(students) { create_student(classroom: klass) }
    scores.each_with_index do |score, index|
      create_exercise_session(student: pupils[index], status: "completed", score_percent: score, classroom_assignment_id: given.first.id)
    end
    klass
  end

  test "AD-12: a student, a teacher, a team member and a detached school admin receive 403" do
    classroom_with("3ème 1", students: 1)

    [ create_student, create_teacher(school: @school), create_team_member, create_user(role: "school_admin") ].each do |outsider|
      sign_in_as outsider

      get school_admin_level_path("3eme")

      assert_response :forbidden, outsider.role
      sign_out
    end
  end

  test "AD-12: a visitor is sent to sign in" do
    get school_admin_level_path("3eme")

    assert_redirected_to new_session_path
  end

  test "AD-11: an unknown level, or a level without an active classroom of the school this year, gives 404" do
    terminale = create_level(name: "Tle", position: 7)
    classroom("Tle D 1", level: terminale, status: "archived")
    classroom("Tle D 2", level: terminale, school_year: "2020-2021")
    classroom("Tle D 3", level: terminale, school: create_school(name: "Lycée Classique d'Abidjan"))
    sign_in_as @admin

    %w[7eme tle 3eme].each do |slug|
      get school_admin_level_path(slug)
      assert_response :not_found, slug
    end
  end

  test "AD-09: one card per classroom, sorted by name, each with the level drawing, its dot, its figures and its link" do
    third = classroom_with("3ème 3", students: 2)
    first = classroom_with("3ème 1", students: 6, assignments: 1, scores: [ 60, 70, 80, 90, 100 ]) # 5 / 6 → 83 %, average 80 %
    second = classroom_with("3ème 2", students: 3, assignments: 2, scores: [ 40, 50 ])              # 2 / 6 → 33 %, no average
    sign_in_as @admin

    get school_admin_level_path("3eme")

    assert_response :success
    assert_select "h1", count: 1, text: "3ème"
    assert_select "p", text: tl("show.subtitle", classrooms: tl("show.classrooms", count: 3), students: tl("show.students", count: 11))
    assert_select "p", text: "3 classes · 11 élèves"
    assert_select "ul#level_classrooms > li" do |cards|
      assert_equal [ first, second, third ].map { "classroom_#{it.public_id}" }, cards.map { it["id"] }
    end
    [ first, second, third ].each do |klass|
      assert_select "#{card(klass)} a", count: 1
      assert_select "#{card(klass)} a[href=?]", school_admin_classroom_path(klass.public_id) do
        assert_select "span.rounded-full.bg-tint-indigo img[alt=''][aria-hidden=true][src*=?]", "levels/3eme", count: 1
        assert_select "p", text: klass.name
        assert_select "span", text: tl("classroom_card.open")
      end
    end

    assert_select card(first) do
      assert_select "span.bg-signal-green[aria-hidden=true]", count: 1
      assert_select "span.sr-only", text: signal_text(:green, :label)
      assert_select "li", text: "6 élèves"
      assert_select "li", text: "1 devoir donné"
      assert_select "li", text: "Taux de rendu : 83 %"
      assert_select "li span.font-medium.text-ink", text: "83 %"
      assert_select "li", text: "Moyenne : 80 %"
      assert_select "span[aria-hidden=true]", text: "—", count: 0
    end
    assert_select card(second) do
      assert_select "span.bg-signal-red[aria-hidden=true]", count: 1
      assert_select "span.sr-only", text: signal_text(:red, :label)
      assert_select "li", text: "3 élèves"
      assert_select "li", text: "2 devoirs donnés"
      assert_select "li", text: "Taux de rendu : 33 %"
      assert_select "li", text: "Moyenne : —#{not_computed}" do
        assert_select "span[aria-hidden=true]", text: "—"
        assert_select "span.sr-only", text: not_computed
      end
    end
    assert_select card(third) do
      assert_select "span[class*=bg-signal]", count: 0
      assert_select "span.sr-only", text: /Signal/, count: 0
      assert_select "li", text: "2 élèves"
      assert_select "li", text: "Aucun devoir donné"
      assert_select "li", text: "Taux de rendu : —#{not_computed}"
      assert_select "li", text: "Moyenne : —#{not_computed}"
    end
    assert_select "#signal_legend", count: 1 do
      %i[green yellow red].each { |signal| assert_select "span", text: signal_text(signal, :legend) }
    end
  end

  test "AD-09, AD-20: the page names its tab, marks « Accueil » and returns to the home page" do
    classroom_with("3ème 1", students: 1)
    sign_in_as @admin

    get school_admin_level_path("3eme")

    assert_select "title", text: "3ème · Direction · Lnclass"
    assert_select "nav a[aria-current=page]", text: I18n.t("shared.navigation.home")
    assert_select "main nav[aria-label=?] a[href=?]", I18n.t("components.back_link.label"), school_admin_classrooms_path,
                  text: tl("show.back")
    assert_select "p", text: "1 classe · 1 élève"
  end

  test "AD-10: another school's, archived or past classrooms of the level never show, nor count" do
    kept = classroom_with("3ème 1", students: 2)
    classroom_with("3ème 8", students: 4, status: "archived")
    classroom_with("3ème 9", students: 4, school_year: "2020-2021")
    classroom_with("3ème 7", students: 4, school: create_school(name: "Lycée Classique d'Abidjan"))
    sign_in_as @admin

    get school_admin_level_path("3eme")

    assert_response :success
    assert_select "ul#level_classrooms > li", count: 1
    assert_select card(kept), count: 1
    assert_select "p", text: "1 classe · 2 élèves"
    assert_no_match(/3ème [789]|Lycée Classique/, response.body)
  end

  test "AD-22: each dot is said in text, a yellow one too, and the page keeps a single h1" do
    yellow = classroom_with("3ème 1", students: 2, assignments: 1, scores: [ 50 ]) # 1 / 2 → 50 %
    sign_in_as @admin

    get school_admin_level_path("3eme")

    assert_select "h1", count: 1
    assert_select card(yellow) do
      assert_select "span.bg-signal-yellow[aria-hidden=true]", count: 1
      assert_select "span.sr-only", text: signal_text(:yellow, :label)
      assert_select "li", text: "Taux de rendu : 50 %"
    end
    assert_select "#signal_legend", count: 1
  end

  test "AD-22: a level whose classrooms have no rate shows neither dot, nor its text, nor the legend" do
    empty = classroom_with("3ème 1", students: 0, assignments: 1)
    idle = classroom_with("3ème 2", students: 3)
    sign_in_as @admin

    get school_admin_level_path("3eme")

    assert_response :success
    assert_select card(empty), text: /Aucun élève/
    assert_select card(empty), text: /1 devoir donné/
    assert_select card(idle), text: /Aucun devoir donné/
    assert_select "span[class*=bg-signal]", count: 0
    assert_select "span.sr-only", text: /Signal/, count: 0
    assert_select "#signal_legend", count: 0
    assert_select "p", text: "2 classes · 3 élèves"
  end

  test "the page reads a fixed number of queries, whatever the number of classrooms" do
    classroom_with("3ème 1", students: 2, assignments: 1, scores: [ 70 ])
    sign_in_as @admin
    get school_admin_level_path("3eme")

    one = count_queries { get school_admin_level_path("3eme") }
    classroom_with("3ème 2", students: 3, assignments: 2, scores: [ 70, 80 ])
    classroom_with("3ème 3", students: 1)

    assert_equal one, count_queries { get school_admin_level_path("3eme") }
    assert_select "ul#level_classrooms > li", count: 3
  end

  private

  # Cached reads count too: the query cache outlives a request in a test, and only a write clears it.
  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end
