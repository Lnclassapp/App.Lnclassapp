require "application_system_test_case"

# CA-12, CA-13, UDR-0006, UDR-0016: the team creates then edits an essential sheet in the modal, its content typed in
# the rich text editor (Trix) under the strict CSP, without a page reload. The course and sheet pages belong to lots
# B1 and B3: the modal is opened by open_in_modal, over the team home.
class Teams::EssentialManagementTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/teams/levels_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    @course = create_course(name: "Génétique et évolution")
    create_essential(course: @course, name: "La méiose")
    sign_in_as create_team_member
    assert_current_path team_home_path
    page.execute_script(<<~JS)
      window.cspViolations = []
      document.addEventListener("securitypolicyviolation", (event) => window.cspViolations.push(event.violatedDirective))
    JS
  end

  # PRD §4: messages are compared through their locale key, never written out in the test.
  def tl(key, **) = I18n.t("teams.essentials.#{key}", **)

  def editor = find("trix-editor#essential_content")

  # The stream refreshes the host page by morphing (turbo:morph): the next modal opens once it is done.
  def expect_refresh
    page.execute_script(<<~JS)
      document.documentElement.removeAttribute("data-test-morphed")
      document.addEventListener("turbo:morph", () => document.documentElement.setAttribute("data-test-morphed", ""), { once: true })
    JS
  end

  def assert_refreshed
    assert_selector "html[data-test-morphed]", visible: :all
  end

  def assert_no_csp_violation
    assert_empty page.evaluate_script("window.cspViolations")
  end

  test "create then edit an essential sheet, its content typed in Trix, without a page reload" do
    assert_no_page_reload do
      open_in_modal(new_teams_course_essential_path(@course.slug))
      within "turbo-frame#modal dialog[open]" do
        assert_selector "#essential-course", text: "Génétique et évolution"
        fill_in "essential[name]", with: "La méiose"
        editor.click
        editor.send_keys("Une phrase")
        click_on tl("new.submit")

        assert_selector "#essential_name_error",
                        text: I18n.t("activemodel.errors.models.dtos/catalog/essential_input.attributes.name.taken")
        assert_field "essential[name]", with: "La méiose"
        assert_selector "trix-editor#essential_content", text: "Une phrase"

        fill_in "essential[name]", with: "Brassage génétique"
        editor.send_keys([ :control, :end ], :enter)
        find("trix-toolbar [data-trix-attribute=bold]").click
        editor.send_keys("Gras")
        find("trix-toolbar [data-trix-attribute=bold]").click
        editor.send_keys(:enter)
        find("trix-toolbar [data-trix-attribute=bullet]").click
        editor.send_keys("Premier point")
        expect_refresh
        click_on tl("new.submit")
      end

      assert_refreshed
      assert_toast tl("create.created", name: "Brassage génétique")
      assert_no_selector "dialog[open]"
    end

    essential = Orm::Essential.find_by!(name: "Brassage génétique")
    html = essential.content.body.to_html
    assert_equal "draft", essential.status
    assert_includes html, "<strong>Gras</strong>"
    assert_includes html, "Une phrase"
    assert_includes html, "<ul><li>Premier point</li></ul>"

    assert_no_page_reload do
      open_in_modal(edit_teams_essential_path(essential.slug))
      within "turbo-frame#modal dialog[open]" do
        assert_selector "trix-editor#essential_content strong", text: "Gras"
        assert_selector "trix-editor#essential_content ul li", text: "Premier point"
        fill_in "essential[name]", with: "Brassage génétique par la méiose"
        expect_refresh
        click_on tl("edit.submit")
      end

      assert_refreshed
      assert_toast tl("update.updated", name: "Brassage génétique par la méiose")
      assert_no_selector "dialog[open]"
    end

    assert_equal "Brassage génétique par la méiose", essential.reload.name
    assert_includes essential.content.body.to_html, "<strong>Gras</strong>"
    assert_no_csp_violation
  end

  test "a file dropped in the editor is refused: no attachment in V1" do
    open_in_modal(new_teams_course_essential_path(@course.slug))
    assert_selector "trix-editor#essential_content"

    page.execute_script(<<~JS)
      document.querySelector("trix-editor#essential_content").editor.insertFile(new File(["x"], "schema.png", { type: "image/png" }))
    JS

    assert_no_selector "trix-editor#essential_content figure"
    assert_equal "", find("input[name='essential[content]']", visible: false).value
    assert_no_csp_violation
  end

  test "on a phone, the modal and its editor never make the page scroll sideways" do
    with_mobile_viewport do
      open_in_modal(new_teams_course_essential_path(@course.slug))

      assert_selector "trix-toolbar"
      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    end
  end
end
