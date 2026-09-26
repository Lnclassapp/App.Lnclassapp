require "test_helper"

# CA-11, AS-37 — UDR-0015. The page of an essential sheet: its content rendered by Action Text, then its exercises. The
# student sees only the published ones, each with his badge, best score and « Commencer » or « Reprendre », and the
# label « Assigné par ton enseignant ». The team sees every exercise and its menu opens in the modal. Outside the team,
# a draft sheet, or a sheet of a draft course, answers 404. The old page showed a fake « Conforme au programme » banner.
class Catalog::EssentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom
    @course = create_course(name: "Génétique et évolution", level: create_level(name: "Tle"), series: create_series(name: "D"),
                            material: create_material(name: "SVT", category: "science"))
    @essential = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions",
                                  content: "<p>Le <strong>brassage</strong> génétique : $2^n$ combinaisons.</p>")
    @exercise = create_exercise(essential: @essential, title: "Méiose et ADN", description: "Deux divisions successives.",
                                position: 1)
    @student = create_student(classroom: @classroom)
  end

  def scope = "catalog.essentials"
  def page_path(essential = @essential) = course_essential_path(essential.course.slug, essential.slug)
  def row_of(exercise) = "#essential_exercise_#{exercise.public_id}"

  test "the student sees the sheet, its content and each published exercise with his progress" do
    doing = create_exercise(essential: @essential, title: "Anomalies", position: 2)
    create_exercise(essential: @essential, title: "Brouillon caché", status: "draft", position: 3)
    create_exercise(essential: @essential, title: "Archive cachée", status: "archived", position: 4)
    best = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 85)
    create_badge(student: @student, exercise: @exercise, level: "gold", session: best)
    started = create_exercise_session(student: @student, exercise: doing)
    create_assignment(classroom: @classroom, assignable: doing)
    sign_in_as @student

    get page_path

    assert_response :success
    assert_select "title", text: /#{I18n.t("#{scope}.show.page_title", name: "La méiose")}/
    assert_select "#essential_header h1", text: "La méiose"
    assert_select "#essential_header", text: /Deux divisions/
    assert_select "#essential_header", text: /SVT/
    assert_select "#essential_header", text: /Tle D/
    assert_select "#essential_header a[href='#{course_path(@course.slug)}']", text: /Génétique et évolution/
    assert_select "#essential_content[data-controller=math] .trix-content strong", text: "brassage"
    assert_select "#essential_exercises li", 2
    assert_select "#essential_exercises", text: /#{I18n.t("#{scope}.show.exercises_count", count: 2)}/
    assert_no_match(/Brouillon caché|Archive cachée/, response.body)

    assert_select row_of(@exercise) do
      assert_select "a[href='#{exercise_path(@exercise.public_id)}']", text: "Méiose et ADN"
      assert_select "*", text: /Deux divisions successives\./
      assert_select "*", text: /#{I18n.t("#{scope}.exercise_progress.badge", level: "Or")}/
      assert_select "*", text: /#{I18n.t("#{scope}.exercise_progress.best_score", score: 85)}/
      assert_select "*", text: /Acquis/
      assert_select "form[method=post][action='#{exercise_sessions_path(@exercise.public_id)}'] button",
                    text: I18n.t("#{scope}.exercise_progress.start")
      assert_select "*", text: /#{I18n.t("#{scope}.exercise_progress.assigned")}/, count: 0
    end
    assert_select row_of(doing) do
      assert_select "*", text: /#{I18n.t("#{scope}.exercise_progress.assigned")}/
      assert_select "*", text: /#{I18n.t("#{scope}.exercise_progress.not_started")}/
      assert_select "a[href='#{exercise_session_path(started.public_id)}']", text: I18n.t("#{scope}.exercise_progress.resume")
      assert_select "form", 0
    end

    assert_select "#essential_team_actions", 0
    assert_select "#content_status_essential_#{@essential.slug}", 0
    assert_select "a[data-turbo-frame=modal]", 0
    assert_select "#essential_gap", 0
  end

  test "the old page's leaks and fake promises are gone: no correct answer, no conformity label, no forbidden word" do
    sign_in_as @student

    get page_path

    assert_response :success
    assert_no_match(/Proposition 1|data-correct/, response.body)
    assert_no_match(/conforme au programme|validation collaborative|habilet/i, response.body)
  end

  test "the student's pending gap on the sheet is announced" do
    create_gap(student: @student, essential: @essential, created_at: Time.zone.local(2026, 9, 12, 10))
    sign_in_as @student

    get page_path

    assert_select "#essential_gap", text: /#{I18n.t("#{scope}.show.gap_title")}/
    assert_select "#essential_gap", text: /12 septembre 2026/
    assert_select "#essential_gap", text: /70 %/
  end

  test "the teacher reads the published exercises, without progress, session button nor team menu" do
    create_exercise(essential: @essential, title: "Brouillon caché", status: "draft")
    sign_in_as create_teacher

    get page_path

    assert_response :success
    assert_select row_of(@exercise) do
      assert_select "a[href='#{exercise_path(@exercise.public_id)}']", text: I18n.t("#{scope}.exercise_progress.open")
      assert_select "form", 0
      assert_select "*", text: /#{I18n.t("#{scope}.exercise_progress.not_started")}/, count: 0
    end
    assert_no_match(/Brouillon caché/, response.body)
    assert_select "#essential_team_actions", 0
  end

  test "the team opens a draft sheet of a draft course: status panel, menu in the modal, every exercise with its status" do
    course = create_course(status: "draft")
    essential = create_essential(course:, name: "Anomalies de la méiose", status: "draft", subtitle: nil)
    create_exercise(essential:, title: "Publié", position: 1)
    create_exercise(essential:, title: "En brouillon", status: "draft", position: 2)
    create_exercise(essential:, title: "Archivé", status: "archived", position: 3)
    sign_in_as create_team_member

    get page_path(essential)

    assert_response :success
    assert_select "#content_status_essential_#{essential.slug}", text: /Brouillon/
    assert_select "#content_status_essential_#{essential.slug} form[action='#{publish_teams_essential_path(essential.slug)}']"
    assert_select "#essential_team_actions" do
      assert_select "a[data-turbo-frame=modal][href='#{edit_teams_essential_path(essential.slug)}']",
                    text: I18n.t("#{scope}.show.edit")
      assert_select "a[data-turbo-frame=modal][href='#{new_teams_essential_exercise_path(essential.slug)}']",
                    text: I18n.t("#{scope}.show.new_exercise")
      assert_select "a[data-turbo-frame=modal][href='#{new_teams_import_path(kind: "exercises", essential: essential.slug)}']",
                    text: I18n.t("#{scope}.show.import_exercises")
    end
    assert_select "#essential_exercises li", 3
    assert_select "#essential_exercises", text: /Brouillon — visible uniquement par l'équipe/
    assert_select "#essential_exercises", text: /Archivé/
    assert_select "#essential_subtitle", 0
    assert_select "#essential_exercises form", 0
  end

  test "empty states: the student learns nothing is published yet, the team is told how to add exercises" do
    empty = create_essential(course: @course, name: "Vide", content: nil)
    create_exercise(essential: empty, status: "draft")
    sign_in_as @student

    get page_path(empty)

    assert_select "#essential_content", text: /#{I18n.t("#{scope}.show.no_content")}/
    assert_select "#essential_exercises", text: /#{I18n.t("#{scope}.show.empty_title")}/
    sign_out

    sign_in_as create_team_member
    get page_path(empty)

    assert_select "#essential_exercises li", 1
    get page_path(create_essential(course: @course, name: "Nue", status: "draft"))

    assert_select "#essential_exercises", text: /#{I18n.t("#{scope}.show.team_empty_title")}/
  end

  test "outside the team, a draft or archived sheet, or a sheet of a draft course, answers 404 without its content" do
    draft = create_essential(course: @course, name: "Brouillon", status: "draft")
    archived = create_essential(course: @course, name: "Archivée", status: "archived")
    in_draft_course = create_essential(course: create_course(status: "draft"), name: "Cours brouillon")

    [ @student, create_teacher ].each do |user|
      sign_in_as user
      [ draft, archived, in_draft_course ].each do |essential|
        get page_path(essential)

        assert_response :not_found
        assert_no_match(/#{essential.name}|L'essentiel à retenir/, response.body)
      end
      sign_out
    end
  end

  test "an unknown sheet, or a sheet read under another course, answers 404" do
    sign_in_as @student

    get course_essential_path(@course.slug, "inconnue")
    assert_response :not_found

    get course_essential_path(create_course.slug, @essential.slug)
    assert_response :not_found
  end

  test "without a session, the page sends to the sign-in" do
    get page_path

    assert_redirected_to new_session_path
  end
end
