require "application_system_test_case"

# CA-01, CA-04, CA-10, TR-41 — UDR-0013. Le catalogue se filtre dans son frame, sans rechargement de page, dès le choix
# d'une liste, et l'URL suit le filtre. La page d'un cours rend son contenu riche, assaini, avec ses formules par KaTeX servi par
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
    # UDR-0013, amendement du 2026-10-01 : l'élève est d'une classe de Tle, le niveau des deux cours.
    sign_in_as create_student_for(@course)
    visit courses_path
    assert_selector "#courses_list > li", count: 2

    assert_no_page_reload do
      # Au changement de la liste, sans « Filtrer », caché avec JavaScript (UDR-0054 §3.9).
      assert_no_button t("catalog.courses.index.filters.submit")
      select "SVT", from: t("catalog.courses.index.filters.material")
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

  # Lot E4 (chantier politique-cache), UDR-0013 amendement du 2026-10-05 : 24 cartes ; la suite arrive quand on descend,
  # sans rechargement de page, et une carte de la suite ouvre son cours en page entière.
  test "the teacher scrolls down the catalogue: the next cards load in place, and one of them opens its course" do
    25.times { |index| create_course(name: format("Cours %02d", index), level: @tle, material: @svt) }
    sign_in_as create_teacher
    visit courses_path
    assert_selector "#courses_total", text: t("catalog.courses.index.total", count: 27)
    assert_selector "#courses_list > li", count: 24
    assert_no_selector "#courses_list_page_2"

    assert_no_page_reload do
      scroll_to find("turbo-frame#courses_page_2")
      assert_selector "#courses_list_page_2 > li", count: 3
      assert_no_selector "turbo-frame#courses_page_3"
    end
    last = all("#courses_list_page_2 > li").last
    name = last.find("h2").text
    last.find("a").click
    assert_selector "h1", text: name
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
      find("button[aria-controls=course-actions-menu]").click
      click_on t("catalog.content_status.actions.publish")
      assert_toast t("teams.courses.transition.published", name: "Mutations")
      assert_selector "#content_status_course_#{course.slug}", text: t("catalog.content_status.published")

      find("button[aria-controls=course-actions-menu]").click
      click_on t("catalog.content_status.actions.archive")
      assert_toast t("teams.courses.transition.archived", name: "Mutations")
      assert_selector "#content_status_course_#{course.slug}", text: t("catalog.content_status.archived")
    end
    assert_equal "archived", course.reload.status
    assert_empty page.evaluate_script("window.cspViolations")
  end

  # ADR-0035, amendement du 2026-10-01 : « Tout publier » depuis le menu ⋮ ; la page fusionnée montre chaque statut publié.
  test "the team publishes a draft course with its sheets and exercises from the ⋮ menu, without a page reload" do
    course = create_course(name: "Mutations", status: "draft")
    essential = create_essential(course:, name: "Les mutations", status: "draft")
    create_exercise(essential:, status: "draft")
    sign_in_as create_team_member
    visit course_path(course.slug)

    assert_no_page_reload do
      find("button[aria-controls=course-actions-menu]").click
      click_on t("catalog.content_status.actions.publish_all")
      assert_toast t("teams.publish_cascade.done.course", name: "Mutations",
                                                          essentials: t("teams.publish_cascade.essentials", count: 1),
                                                          exercises: t("teams.publish_cascade.exercises", count: 1))
      assert_selector "#content_status_course_#{course.slug}", text: t("catalog.content_status.published")
      assert_selector "#essential_#{essential.slug}", text: t("catalog.content_status.published")
    end
    assert_equal %w[published published published], [ course, essential, essential.exercises.first ].map { it.reload.status }
  end

  test "on a phone, the catalogue and the course page never scroll sideways" do
    # UDR-0013, amendement du 2026-10-01 : l'élève est d'une classe du niveau du cours.
    sign_in_as create_student_for(@course)
    with_mobile_viewport do
      [ courses_path, course_path(@course.slug) ].each do |path|
        visit path
        assert_selector "h1"
        assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "#{path} défile sur le côté"
      end
    end
  end

  # UDR-0013, amendement du 2026-10-02 (UDR-0057) : le catalogue filtré par matière et la page cours, vus par l'élève à
  # 390 × 844, passent la règle de sobriété ; le niveau quitte les cartes. Amendement du 2026-10-05 ter : la matière
  # filtrée y reste (badge), avec le pied « Ouvrir le cours → ».
  test "on a phone, the student's catalogue filtered by subject and the course page pass the sobriety rule" do
    %w[Mitose Mutations Hérédité].each { create_essential(course: @course, name: it) }
    sign_in_as create_student_for(@course)

    with_mobile_viewport do
      visit courses_path(material: @svt.slug)
      assert_selector "#courses_list > li", count: 1
      assert_single_primary_action
      assert_blocks_above_fold "#main > div > *", max: 5
      within("#course_#{@course.slug}") do
        assert_text "SVT"
        assert_text t("catalog.courses.course_card.open")
        assert_no_text "Tle"
      end
      assert_selector "#main details summary", visible: :all,
                                               text: t("components.info_tip.label", label: t("catalog.courses.index.student_scope_label"))

      visit course_path(@course.slug)
      assert_single_primary_action
      assert_blocks_above_fold "#main > div > *", max: 5
      assert_list_capped "#course_essentials ul"
      assert_no_text "Hérédité"
      assert_no_page_reload { click_on t("components.reveal.more") }
      assert_selector "#course_essentials li", text: "Hérédité"

      # The whole row is the link: a tap anywhere on it opens the sheet.
      find("#course_essentials li", text: "Mitose").click
      assert_selector "#essential_header h1", text: "Mitose"
    end
  end

  # Décision du porteur du 2026-10-02 : les retraits ne valent que pour l'élève. ADR-0072, UDR-0013 (amendée le
  # 2026-10-02) : seul « Assigner à mes classes » quitte la page du cours, un cours ne s'assignant plus.
  test "on a phone, the teacher's filtered catalogue and course page are unchanged, without « Assigner à mes classes »" do
    %w[Mitose Mutations Hérédité].each { create_essential(course: @course, name: it) }
    sign_in_as create_teacher

    with_mobile_viewport do
      visit courses_path(material: @svt.slug)
      within("#course_#{@course.slug}") do
        assert_text "SVT"
        assert_text "Tle"
      end

      visit course_path(@course.slug)
      assert_selector "#course_essentials li", count: 4
      assert_no_button t("components.reveal.more")
      assert_no_link "Assigner à mes classes"
      assert_no_button "Assigner à mes classes"
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
