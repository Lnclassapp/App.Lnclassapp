require "test_helper"

# AD-12, AD-17, AD-19 (UDR-0074 §3.11): « Activité récente », the lazy frame of the direction's home. The address answers
# its frame alone, without the shell; the school is always the account's, never a parameter; any other role gets 403.
class SchoolAdmin::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  FRAME = "turbo-frame#direction_home_activity_feed".freeze

  setup do
    # A Sunday: « Hier » is Saturday 3 October, and Tuesday 29 September is five days earlier.
    travel_to Time.zone.local(2026, 10, 4, 11, 0)
    @school = create_school(name: "Lycée moderne de Cocody")
    @admin = create_school_admin(school: @school)
    @troisieme_2 = create_classroom(school: @school, level: create_level(name: "3ème"), name: "3ème 2")
    @sixieme_1 = create_classroom(school: @school, level: create_level(name: "6ème"), name: "6ème 1")
    @kouassi = teacher(gender: "male", first_name: "Yao", last_name: "Kouassi")
  end

  def teacher(at: 90.days.ago, school: @school, **)
    create_teacher(school:, **).tap { Orm::TeacherSchool.where(teacher: it).update_all(created_at: at) }
  end

  def joined(classroom, at:, **)
    create_student(classroom:, **).tap { Orm::ClassroomStudent.where(student: it).update_all(joined_at: at) }
  end

  def given(classroom, at:, by: @kouassi, title: "Exercice #{factory_sequence}")
    create_assignment(classroom:, assignable: create_exercise(title:, questions: 0), by:, assigned_at: at)
  end

  # Days of October up to the 4th, of September after.
  def moment(day, hour, minute) = Time.zone.local(2026, day > 4 ? 9 : 10, day, hour, minute)

  # The first drawing of a mini Heroicon, as ui_icon serves it (UDR-0074 §3.11: one icon per kind of event).
  def icon_path(name) = Nokogiri::XML(Rails.root.join("vendor/heroicons/20/solid/#{name}.svg").read).at_css("path")["d"]

  test "AD-17: the activity answers its frame alone, without the shell, one title per day, the most recent first" do
    given(@troisieme_2, at: moment(4, 10, 42), title: "Les fractions")
    joined(@sixieme_1, at: moment(4, 8, 15), first_name: "Moussa", last_name: "Bamba")
    joined(@sixieme_1, at: moment(3, 16, 5), first_name: "Awa", last_name: "Koné")
    teacher(at: moment(29, 9, 30), gender: "female", first_name: "Mariam", last_name: "Traoré")
    sign_in_as @admin

    get school_admin_activity_path

    assert_response :success
    assert_match(/\A<turbo-frame id="direction_home_activity_feed"/, response.body.strip)
    assert_no_match(/<html|<body|<head/, response.body)
    assert_select "nav, h1, h2", count: 0
    assert_select "#{FRAME}[target=_top]" do
      assert_select "h3", count: 3
      assert_select "h3 + ul.divide-y", count: 3
      assert_select "ul > li", count: 4
    end
    assert_equal [ "Aujourd'hui", "Hier", "Mardi 29 sept." ], css_select("h3").map { it.text.strip }
    assert_equal [ "M. Kouassi a donné « Les fractions » à 3ème 2", "Moussa B. a rejoint 6ème 1", "Awa K. a rejoint 6ème 1",
                   "Mme Traoré a rejoint l'établissement" ], css_select("li p").map { it.text.strip }
    assert_equal [ 2, 1, 1 ], css_select("h3 + ul").map { it.css("li").size }
  end

  test "AD-17: each line has its icon and its hour, « 10:42 », in a <time> with the ISO instant" do
    given(@troisieme_2, at: moment(4, 10, 42))
    joined(@sixieme_1, at: moment(3, 16, 5))
    teacher(at: moment(29, 9, 30))
    sign_in_as @admin

    get school_admin_activity_path

    assert_equal [ "10:42", "16:05", "09:30" ], css_select("li time").map { it.text.strip }
    assert_equal [ moment(4, 10, 42), moment(3, 16, 5), moment(29, 9, 30) ].map(&:iso8601), css_select("li time").map { it["datetime"] }
    assert_select "li > span.rounded-full svg[aria-hidden=true]", count: 3
    assert_equal %w[clipboard-document-list user-plus academic-cap].map { icon_path(it) },
                 css_select("li > span.rounded-full svg path:first-child").map { it["d"] }
  end

  test "AD-17: the classroom name links to its page; a teacher's arrival has no link" do
    given(@troisieme_2, at: 1.hour.ago, title: "Les fractions")
    joined(@sixieme_1, at: 2.hours.ago, first_name: "Awa", last_name: "Koné")
    teacher(at: 3.hours.ago, last_name: "Traoré")
    sign_in_as @admin

    get school_admin_activity_path

    assert_select "li p a", count: 2
    assert_select "li p a[href=?]", school_admin_classroom_path(@troisieme_2.public_id), text: "3ème 2"
    assert_select "li p a[href=?]", school_admin_classroom_path(@sixieme_1.public_id), text: "6ème 1"
    assert_select "li:last-child p a", count: 0
  end

  test "AD-17: an anonymized teacher is « Un enseignant », a teacher by her civility and her last name" do
    given(@troisieme_2, at: 1.hour.ago, title: "Les fractions", by: teacher(gender: "male", last_name: "Yao", anonymized_at: 1.day.ago))
    given(@troisieme_2, at: 2.hours.ago, title: "Le théorème de Thalès", by: teacher(gender: "female", last_name: "Traoré"))
    sign_in_as @admin

    get school_admin_activity_path

    assert_equal [ "Un enseignant a donné « Les fractions » à 3ème 2", "Mme Traoré a donné « Le théorème de Thalès » à 3ème 2" ],
                 css_select("li p").map { it.text.strip }
    assert_no_match(/Yao/, response.body)
  end

  test "AD-17: a title is written as text, never as markup" do
    given(@troisieme_2, at: 1.hour.ago, title: "<b>Les fractions</b>")
    sign_in_as @admin

    get school_admin_activity_path

    assert_select "li p b", count: 0
    assert_select "li p", text: "M. Kouassi a donné « <b>Les fractions</b> » à 3ème 2"
  end

  test "AD-19: nothing in the last 30 days reads « Rien de nouveau ces 30 derniers jours »" do
    given(@troisieme_2, at: 31.days.ago)
    sign_in_as @admin

    get school_admin_activity_path

    assert_response :success
    assert_select FRAME do
      assert_select "p", text: "Rien de nouveau ces 30 derniers jours"
      assert_select "h3, li", count: 0
    end
  end

  test "the school is the account's, never a parameter" do
    other = create_school(name: "Lycée classique d'Abidjan")
    given(create_classroom(school: other, name: "Tle D 9"), at: 1.hour.ago, title: "Ailleurs")
    sign_in_as @admin

    get school_admin_activity_path(school_id: other.id)

    assert_select FRAME, text: /Rien de nouveau ces 30 derniers jours/
    assert_no_match(/Ailleurs|Tle D 9/, response.body)
  end

  test "a failing read shows the common error state in the frame, with « Réessayer » back to the home" do
    failing = Object.new.tap { it.define_singleton_method(:call) { |**| raise ActiveRecord::ConnectionNotEstablished } }
    Queries::School::SchoolActivityQuery.define_singleton_method(:new) { failing }
    sign_in_as @admin

    get school_admin_activity_path

    assert_response :service_unavailable
    assert_select "#{FRAME} [role=alert]" do
      assert_select "a[href=?]", school_admin_classrooms_path, text: /#{I18n.t("components.error_state.retry")}/
    end
  ensure
    Queries::School::SchoolActivityQuery.singleton_class.remove_method(:new)
  end

  # Constat du challenger (phase 5, D1) : demandée en JSON ou en XML, l'activité levait MissingTemplate (500). Comme les pages
  # voisines, elle refuse un format qu'elle ne sait pas rendre, sans lire la base.
  test "the activity refuses any format but HTML with 406, without reading" do
    sign_in_as @admin
    reads = 0
    counter = ->(*, payload) { reads += 1 if payload[:sql].include?("classroom_assignments") }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get school_admin_activity_path(format: :json)
      assert_response :not_acceptable
      get school_admin_activity_path, headers: { "Accept" => "application/json" }
      assert_response :not_acceptable
      get school_admin_activity_path(format: :xml)
      assert_response :not_acceptable
    end
    assert_equal 0, reads
  end

  test "AD-12: the team, a teacher, a student and a detached school admin receive 403" do
    [ create_team_member, @kouassi, create_student(classroom: @sixieme_1), create_user(role: "school_admin") ].each do |outsider|
      sign_in_as outsider

      get school_admin_activity_path

      assert_response :forbidden, outsider.role
      sign_out
    end
  end

  test "AD-12: another school's direction reads its own activity only" do
    other = create_school(name: "Lycée classique d'Abidjan")
    given(@troisieme_2, at: 1.hour.ago, title: "Les fractions")
    sign_in_as create_school_admin(school: other)

    get school_admin_activity_path

    assert_select FRAME, text: /Rien de nouveau ces 30 derniers jours/
    assert_no_match(/Les fractions/, response.body)
  end

  test "a visitor is sent to sign in" do
    get school_admin_activity_path

    assert_redirected_to new_session_path
  end
end
