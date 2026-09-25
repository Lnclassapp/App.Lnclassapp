require "application_system_test_case"

# CA-05, CA-06, UDR-0006, UDR-0014: the team creates then edits a course in the modal, its content typed in the rich
# text editor (Trix, loaded on demand under the strict CSP, no attachment) — every write without a page reload.
# The « Nouveau cours » and « Modifier » buttons live in the screens of lot B1: the modal is opened by open_in_modal
# from the imports screen of the socle (plan, Hotwire rule 7).
class Teams::CourseManagementTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/teams/series_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  CONTENT = "<div><strong>ADN</strong> et gènes</div><ul><li>Transcription</li><li>Traduction</li></ul>".freeze

  setup do
    @tle = create_level(name: "Tle", position: 7)
    link_level_series(level: @tle, series: create_series(name: "D"))
    @svt = create_material(name: "SVT", shortname: "SVT")
    sign_in_as create_team_member
    assert_current_path team_home_path
    visit teams_imports_path
    # Any violation of the Content Security Policy is recorded, to be asserted empty.
    page.execute_script(<<~JS)
      window.cspViolations = []
      document.addEventListener("securitypolicyviolation", (event) => window.cspViolations.push(event.violatedDirective))
    JS
  end

  def t(key, **) = I18n.t(key, **)
  def editor_html = page.evaluate_script("document.querySelector('trix-editor').innerHTML")

  test "create a course in the modal, its content in bold and in a bulleted list, a dropped file refused" do
    assert_no_page_reload do
      mark_host_page
      open_in_modal(new_teams_course_path)
      within "turbo-frame#modal dialog[open]" do
        assert_selector "trix-toolbar [data-trix-attribute=bold]"
        assert_no_selector "trix-toolbar [data-trix-action=attachFiles]"

        fill_in "course[name]", with: "   "
        select "Tle", from: "course[level_slug]"
        select "SVT", from: "course[material_slug]"
        click_on t("teams.courses.new.submit")
        assert_selector "#course_name_error", text: t("activemodel.errors.models.dtos/catalog/course_input.attributes.name.blank")

        fill_in "course[name]", with: "génétique et évolution"
        select "D", from: "course[series_slug]"
        editor = find("trix-editor")
        editor.click
        find("trix-toolbar [data-trix-attribute=bold]").click
        editor.send_keys("ADN")
        find("trix-toolbar [data-trix-attribute=bold]").click
        editor.send_keys(" et gènes", :enter)
        find("trix-toolbar [data-trix-attribute=bullet]").click
        editor.send_keys("Transcription", :enter, "Traduction")

        drop_file_on_editor
        assert_no_selector "trix-editor figure, trix-editor [data-trix-attachment]"
        click_on t("teams.courses.new.submit")
      end
      assert_toast t("teams.courses.create.created", name: "génétique et évolution")
      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_refreshed_with_toast t("teams.courses.create.created", name: "génétique et évolution")
    end

    course = Orm::Course.sole
    assert_equal [ "génétique et évolution", "draft" ], [ course.name, course.status ]
    html = course.content.body.to_html
    assert_includes html, "<strong>ADN</strong>"
    assert_match %r{<ul><li>Transcription</li><li>Traduction</li></ul>}, html
    assert_not_includes html, "attachment"
    assert_empty page.evaluate_script("window.cspViolations")
  end

  test "edit a course: its saved content comes back in the editor, an error reopens the modal, the update closes it" do
    course = create_course(name: "Génétique", level: @tle, material: @svt, content: CONTENT)

    assert_no_page_reload do
      mark_host_page
      open_in_modal(edit_teams_course_path(course.slug))
      within "turbo-frame#modal dialog[open]" do
        assert_selector "trix-editor strong", text: "ADN"
        assert_selector "trix-editor ul li", text: "Traduction"

        fill_in "course[name]", with: "   "
        click_on t("teams.courses.edit.submit")
        assert_selector "#course_name_error", text: t("activemodel.errors.models.dtos/catalog/course_input.attributes.name.blank")
        assert_selector "trix-editor strong", text: "ADN"

        fill_in "course[name]", with: "Génétique et évolution"
        click_on t("teams.courses.edit.submit")
      end
      assert_toast t("teams.courses.update.updated", name: "Génétique et évolution")
      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_refreshed_with_toast t("teams.courses.update.updated", name: "Génétique et évolution")
    end

    course.reload
    assert_equal [ "Génétique et évolution", "genetique" ], [ course.name, course.slug ]
    assert_includes course.content.body.to_html, "<strong>ADN</strong>"
    assert_empty page.evaluate_script("window.cspViolations")
  end

  test "on a phone, the course modal never makes the page scroll sideways" do
    with_mobile_viewport do
      open_in_modal(new_teams_course_path)
      assert_selector "trix-toolbar"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile sur le côté"
    end
  end

  private

  # The host page is re-requested and morphed (turbo_stream.refresh): the morph drops this attribute, absent from
  # the server's HTML. The toast must survive it (each toast is permanent).
  def mark_host_page = page.execute_script("document.querySelector('main').dataset.beforeRefresh = 'true'")

  def assert_refreshed_with_toast(text)
    assert_no_selector "main[data-before-refresh]"
    assert_toast text
  end

  # A real drop of a file, as the browser sends it: Trix asks trix-file-accept, which the editor controller refuses.
  def drop_file_on_editor
    page.execute_script(<<~JS)
      const editor = document.querySelector("trix-editor")
      const transfer = new DataTransfer()
      transfer.items.add(new File(["png"], "photo.png", { type: "image/png" }))
      for (const type of ["dragenter", "dragover", "drop"]) {
        editor.dispatchEvent(new DragEvent(type, { dataTransfer: transfer, bubbles: true, cancelable: true }))
      }
    JS
  end
end
