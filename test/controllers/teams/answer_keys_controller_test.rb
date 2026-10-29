require "test_helper"

# UDR-0141 §3.5, CA-15 et CA-16 : le corrigé d'une leçon est réservé à l'équipe ; tout autre acteur reçoit 404.
class Teams::AnswerKeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Racines carrées", status: "draft", figures: [ revision_figure ])
    @n1 = create_essential(course: @course, name: "Simplifier", position: 1, status: "draft")
    @ex = create_exercise(essential: @n1, title: "Exercice A", status: "draft", position: 5, figure_key: "triangle-thales")
    @ex.questions.order(:position).first.update!(explanation: "Correction rédigée de la question 1.")
    @wide = create_lesson_wide_exercise(course: @course, title: "Problème 1", status: "draft", position: 1)
  end

  def tl(key, **) = I18n.t("teams.answer_keys.#{key}", **)

  test "CA-15: the team reads each exercise in the Prépare interros order, with right answers and corrections" do
    sign_in_as create_team_member

    get answer_key_teams_course_path(@course.slug)

    assert_response :success
    assert_select "h1", text: /Racines carrées/
    assert_select "section[id^=exercise-]", 2
    assert_select "section[id^=exercise-]:first-of-type h2", text: "Exercice A"
    assert_select "section#exercise-#{@ex.public_id} figure[data-controller=figure]"
    assert_select "section#exercise-#{@ex.public_id}", text: /Correction rédigée de la question 1\./
    assert_select "section#exercise-#{@ex.public_id} .sr-only", text: tl("show.right_answer"), minimum: 1
    assert_select "section#exercise-#{@wide.public_id}", text: /#{Regexp.escape(tl("show.lesson_wide", group: I18n.t("catalog.courses.show.lesson_wide_title"), number: 1))}/
    assert_select "section#exercise-#{@wide.public_id} figure", 0
    assert_select "a[href='#{course_path(@course.slug)}']"
  end

  test "an empty lesson shows the empty state" do
    sign_in_as create_team_member

    get answer_key_teams_course_path(create_course(status: "draft").slug)

    assert_response :success
    assert_select "section[id^=exercise-]", 0
    assert_select "p", text: tl("show.empty")
  end

  test "CA-16: a visitor who is not signed in is sent to the sign-in page, without the correction" do
    get answer_key_teams_course_path(@course.slug)

    assert_redirected_to new_session_path
    assert_no_match(/Correction rédigée/, response.body)
  end

  test "CA-16: a school administration account receives 404" do
    sign_in_as create_school_admin

    get answer_key_teams_course_path(@course.slug)

    assert_response :not_found
    assert_no_match(/Correction rédigée/, response.body)
  end

  test "CA-16: a student and a teacher receive 404" do
    [ create_student, create_teacher ].each do |user|
      sign_in_as user
      get answer_key_teams_course_path(@course.slug)
      assert_response :not_found
      assert_no_match(/Correction rédigée/, response.body)
      sign_out
    end
  end

  test "an unknown lesson answers 404 for the team" do
    sign_in_as create_team_member

    get answer_key_teams_course_path("inconnue")

    assert_response :not_found
  end

  test "the menu of a draft lesson offers the answer key and no longer the notion import" do
    sign_in_as create_team_member

    get course_path(@course.slug)

    assert_response :success
    assert_select "#course-actions-menu a[href='#{answer_key_teams_course_path(@course.slug)}']", text: tl("menu")
    assert_select "#course-actions-menu a[href*='kind=essentials']", 0
  end
end
