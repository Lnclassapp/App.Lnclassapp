require "application_system_test_case"

# Finitions UX, lot C2 (UDR-0054 §3.1 to §3.3): the team's content and import screens. Each modal (course, essential,
# exercise, import) names the tab while open, gives it back on close, and targets its first field (FU-05, FU-15);
# the import report goes back to « Imports » by the common link (FU-10, FU-11); no title keeps a colon.
module Finitions; end

class Finitions::TeamContentTest < ApplicationSystemTestCase
  setup do
    @essential = create_essential(course: create_course(name: "Génétique et évolution"), name: "La méiose")
    @exercise = create_exercise(essential: @essential)
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def t(key, **) = I18n.t(key, **)
  def team_title(page) = "#{page} · Équipe · Lnclass"
  def focused_id = evaluate_script("document.activeElement.id")

  test "FU-05: the course modal opened by its URL has its title, and its focus on the name" do
    visit new_teams_course_path

    assert_selector "dialog#course-modal[open]"
    assert_equal team_title("Nouveau cours"), page.title
    assert_equal "course_name", focused_id
  end

  test "each content and import modal names the tab while open, targets its first field, and gives the tab back" do
    visit teams_imports_path
    assert_equal team_title("Imports"), page.title

    {
      new_teams_course_path => [ "course-modal", "Nouveau cours", "course_name" ],
      edit_teams_course_path(@essential.course.slug) => [ "course-modal", "Modifier le cours", "course_name" ],
      new_teams_course_essential_path(@essential.course.slug) => [ "essential-modal", "Nouvelle fiche essentielle", "essential_name" ],
      edit_teams_essential_path(@essential.slug) => [ "essential-modal", "Modifier la fiche essentielle", "essential_name" ],
      new_teams_essential_exercise_path(@essential.slug) => [ "exercise-modal", "Nouvel exercice", "exercise_title" ],
      edit_teams_exercise_path(@exercise.public_id) => [ "exercise-modal", "Modifier l'exercice", "exercise_title" ],
      new_teams_import_path(kind: "drenas") => [ "import-upload-modal", "Importer des DRENA", "import_files" ],
      new_teams_import_path(kind: "course_tree") => [ "import-upload-modal", "Importer des cours complets", "import_files" ]
    }.each do |path, (id, title, field)|
      open_in_modal(path)

      assert_selector "dialog##{id}[open]"
      assert_equal field, focused_id, path
      assert_equal team_title(title), page.title, path

      find("dialog##{id}").send_keys(:escape)
      assert_no_selector "dialog##{id}", visible: :all
      assert_equal team_title("Imports"), page.title, path
    end
  end

  test "a course sent with an empty name comes back in 422 with the focus on that name" do
    visit teams_imports_path
    open_in_modal(new_teams_course_path)

    within("dialog#course-modal") do
      fill_in "course[name]", with: "   "
      select @essential.course.level.name, from: "course[level_slug]"
      select @essential.course.material.name, from: "course[material_slug]"
      click_on t("teams.courses.new.submit")
      assert_selector "#course_name[aria-invalid=true]"
    end
    assert_equal "course_name", focused_id
    assert_equal team_title("Nouveau cours"), page.title
  end

  test "FU-10, FU-11: the import report goes back to « Imports » by the common link, its tab title without a colon" do
    report = create_import_report(kind: "schools", status: "completed", finished_at: Time.current)

    visit teams_import_path(report.public_id)

    assert_equal team_title("Import d'établissements"), page.title
    first_link = find("main a", match: :first)
    assert_equal "Imports", first_link.text
    assert_equal teams_imports_path, URI(first_link[:href]).path
    assert_selector "main nav[aria-label='#{t('components.back_link.label')}'] a[href='#{teams_imports_path}']"
    assert_no_text "Retour aux imports"
  end

  test "the class generation report is named after its kind, and goes back to « Imports »" do
    report = create_import_report(kind: "classrooms", status: "completed", finished_at: Time.current)

    visit teams_import_path(report.public_id)

    assert_equal team_title(t("import_kinds.classrooms")), page.title
    assert_selector "main nav[aria-label='#{t('components.back_link.label')}'] a[href='#{teams_imports_path}']", text: "Imports"
  end
end
