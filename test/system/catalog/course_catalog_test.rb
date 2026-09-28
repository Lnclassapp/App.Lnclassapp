require "application_system_test_case"

# CA-01, CA-04, CA-10, TR-41 — UDR-0013. Le catalogue se filtre dans son frame, sans rechargement de page, et l'URL
# suit le filtre. La page d'un cours rend son contenu riche, assaini, avec ses formules par KaTeX servi par
# l'application. L'équipe y modifie le contenu dans l'éditeur riche (modale du Lot B2), puis publie et archive le cours
# depuis le panneau de statut : chaque écriture sans rechargement de page, les formules toujours rendues après morphing.
class Catalog::CourseCatalogTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/teams/course_management_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true, formats: :html) })
  end

  setup do
    @tle = create_level(name: "Tle", position: 7)
    @svt = create_material(name: "SVT", category: "science")
    @philo = create_material(name: "Philosophie", category: "literature")
    @course = create_course(name: "Génétique et évolution", level: @tle, material: @svt,
                            content: "<div>L'aire du disque vaut $\\pi r^2$.</div>")
    create_course(name: "La conscience", level: @tle, material: @philo)
    create_essential(course: @course, name: "La méiose")
  end

  def t(key, **) = I18n.t(key, **)

  test "a student filters the catalogue by subject without a page reload, then opens a course whose formula KaTeX renders" do
    sign_in_as create_student
    visit courses_path
    assert_selector "#courses_list > li", count: 2

    assert_no_page_reload do
      select "SVT", from: t("catalog.courses.index.filters.material")
      click_on t("catalog.courses.index.filters.submit")
      assert_selector "#courses_list > li", count: 1
      assert_selector "#course_#{@course.slug}"
      assert_current_path(/\A#{courses_path}\?.*material=#{@svt.slug}/)
    end

    assert_no_page_reload do
      find("#course_#{@course.slug} a").click
      assert_selector "#course_header h1", text: "Génétique et évolution"
    end
    assert_current_path course_path(@course.slug)
    assert_selector "#course_content .katex", count: 1
    assert_selector "#course_essentials li", text: "La méiose"

    assert_not resource_loaded?("trix"), "une page sans formulaire ne charge pas Trix"
    assert page.evaluate_script("performance.getEntriesByType('resource').every((entry) => entry.name.startsWith(location.origin))"),
           "une ressource vient d'un hôte tiers"
  end

  test "the team edits the content in the rich text editor from the course page, then publishes and archives it, without a page reload" do
    course = create_course(name: "Mutation et diversité", level: @tle, material: @svt, status: "draft",
                           content: "<div>Probabilité : $\\frac{1}{2}$</div>")
    sign_in_as create_team_member
    assert_current_path team_home_path
    visit course_path(course.slug)
    assert_selector "#course_content .katex", count: 1
    # Any violation of the Content Security Policy is recorded, to be asserted empty.
    page.execute_script(<<~JS)
      window.cspViolations = []
      document.addEventListener("securitypolicyviolation", (event) => window.cspViolations.push(event.violatedDirective))
    JS

    assert_no_page_reload do
      find("button[aria-controls=course-actions-menu]").click
      click_on t("catalog.courses.role_actions.edit")
      within "turbo-frame#modal dialog[open]" do
        editor = find_rich_text_editor
        editor.click
        page.execute_script("const editor = arguments[0].editor; editor.setSelectedRange(editor.getDocument().getLength() - 1)", editor)
        editor.send_keys(:enter)
        find("trix-toolbar [data-trix-attribute=bold]").click
        editor.send_keys("Mutation ponctuelle")
        smuggle_unsafe_html
        click_on t("teams.courses.edit.submit")
      end
      assert_toast t("teams.courses.update.updated", name: "Mutation et diversité")
      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_selector "#course_content strong", text: "Mutation ponctuelle"
      assert_selector "#course_content .katex", count: 1
    end
    stored = course.reload.content.body.to_html
    assert_includes stored, "<strong>Mutation ponctuelle</strong>"
    assert_no_match(/<script|onclick|javascript:/, stored)
    assert_no_match(/<script>window\.hacked|onclick=|javascript:/, page.html)

    # The content is unchanged this time: after the morph, its formula is still rendered, not left as raw « $…$ ».
    assert_no_page_reload do
      find("button[aria-controls=course-actions-menu]").click
      click_on t("catalog.courses.role_actions.edit")
      within "turbo-frame#modal dialog[open]" do
        fill_in "course[name]", with: "Mutations"
        click_on t("teams.courses.edit.submit")
      end
      assert_selector "#course_header h1", text: "Mutations"
      assert_selector "#course_content .katex", count: 1
      assert_no_text "$\\frac{1}{2}$"
    end

    assert_no_page_reload do
      within("#content_status_course_#{course.slug}") { click_on t("catalog.content_status.actions.publish") }
      assert_toast t("teams.courses.transition.published", name: "Mutations")
      assert_selector "#content_status_course_#{course.slug}", text: t("catalog.content_status.published")

      within("#content_status_course_#{course.slug}") { click_on t("catalog.content_status.actions.archive") }
      assert_toast t("teams.courses.transition.archived", name: "Mutations")
      assert_selector "#content_status_course_#{course.slug}", text: t("catalog.content_status.archived")
    end
    assert_equal "archived", course.reload.status
    assert_empty page.evaluate_script("window.cspViolations")
  end

  test "on a phone, the catalogue and the course page never scroll sideways" do
    sign_in_as create_student
    with_mobile_viewport do
      [ courses_path, course_path(@course.slug) ].each do |path|
        visit path
        assert_selector "h1"
        assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "#{path} défile sur le côté"
      end
    end
  end

  private

  def resource_loaded?(name) = page.evaluate_script("performance.getEntriesByType('resource').some((entry) => entry.name.includes(arguments[0]))", name)

  # What a forged request would send: the editor's hidden field, completed after the last keystroke with a script, an
  # event attribute and a javascript: link. The server (RichTextSanitizer, then Action Text on render) must drop them.
  def smuggle_unsafe_html
    page.execute_script(<<~JS)
      const input = document.querySelector("input[name='course[content]']")
      input.value += '<script>window.hacked = true</script><p onclick="window.hacked = true">clic</p><a href="javascript:alert(1)">lien</a>'
    JS
  end
end
