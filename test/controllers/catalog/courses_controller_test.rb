require "test_helper"

# CA-01, CA-04, CA-10, CA-26, CA-27, TR-41 — UDR-0013. Le catalogue et la page d'un cours, pour tous les rôles connectés.
# L'ancienne application ignorait les filtres, laissait lire un brouillon par URL directe, colorait la matière d'après
# son nom, et n'affichait jamais « Assigner à mes classes ». Ici : filtres par slug, 404 hors équipe pour tout cours non
# publié, couleur tirée de la catégorie, points d'entrée de l'équipe en modale, lien d'assignation pour l'enseignant.
class Catalog::CoursesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tle = create_level(name: "Tle", position: 7)
    @seconde = create_level(name: "2nde", position: 5)
    @svt = create_material(name: "SVT", category: "science")
    @philo = create_material(name: "Philosophie", category: "literature")
    @course = create_course(name: "Génétique et évolution", subtitle: "Du gène à l'espèce", level: @tle,
                            series: create_series(name: "D"), material: @svt,
                            content: "<div><strong>ADN</strong> et gènes : $x^2$</div>")
    @published = create_course(name: "La conscience", level: @tle, material: @philo)
    @draft = create_course(name: "Brouillon de cours", level: @seconde, material: @svt, status: "draft")
    @archived = create_course(name: "Cours archivé", level: @seconde, material: @svt, status: "archived")
  end

  def tl(key, **) = I18n.t("catalog.courses.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def modal_link(href) = "a[href='#{href}'][data-turbo-frame=modal]"
  def status_label(status) = I18n.t("catalog.content_status.#{status}")

  test "a visitor is sent to the sign-in" do
    get courses_path
    assert_redirected_to new_session_path

    get course_path(@course.slug)
    assert_redirected_to new_session_path
  end

  # ── Catalogue ──────────────────────────────────────────────────────────────

  test "a student sees the published courses only, as cards, without team actions nor status" do
    sign_in_as create_student

    get courses_path

    assert_response :success
    assert_select "title", text: tl("index.page_title")
    assert_select "h1", text: tl("index.title")
    assert_select "turbo-frame#courses[data-turbo-action=advance][target=_top] #courses_list > li", 2
    assert_select "#courses_list li:first-child", text: /Philosophie.*Tle.*La conscience/m
    assert_select "#course_#{@course.slug} a[href='#{course_path(@course.slug)}']" do
      assert_select "*", text: including("SVT")
      assert_select "*", text: including("Tle D")
      assert_select "h2", text: "Génétique et évolution"
      assert_select "*", text: including("Du gène à l'espèce")
      assert_select "*", text: including(tl("course_card.open"))
    end
    assert_no_match(/Brouillon de cours|Cours archivé/, response.body)
    assert_no_match(including(status_label(:published)), response.body)
    assert_select "a[href='#{new_teams_course_path}']", 0
    assert_select "a[href^='#{new_teams_import_path}']", 0
  end

  test "the team sees every course with its status, and opens « Nouveau cours » and « Importer des cours » in the modal" do
    sign_in_as create_team_member

    get courses_path

    assert_response :success
    assert_select "#courses_list > li", 4
    assert_select "#course_#{@draft.slug}", text: including(status_label(:draft))
    assert_select "#course_#{@archived.slug}", text: including(status_label(:archived))
    assert_select "#course_#{@course.slug}", text: including(status_label(:published))
    assert_select modal_link(new_teams_course_path), text: tl("index.new_course")
    assert_select modal_link(new_teams_import_path(kind: "course_tree")), text: tl("index.import")
  end

  test "the filters list the levels and materials, and keep the chosen ones" do
    sign_in_as create_student

    get courses_path(material: @svt.slug)

    assert_select "form#courses-filters[method=get][action='#{courses_path}'][data-turbo-frame=courses][data-turbo-action=advance]" do
      assert_select "select[name=level] option", 3
      assert_select "select[name=level] option[value='#{@tle.slug}']", text: "Tle"
      assert_select "select[name=material] option[selected][value='#{@svt.slug}']", text: "SVT"
    end
    assert_select "#courses_list > li", 1
    assert_select "#course_#{@course.slug}"
  end

  test "a request from the courses frame receives the frame only, filtered" do
    sign_in_as create_student

    get courses_path(level: @tle.slug, material: @philo.slug), headers: { "Turbo-Frame" => "courses" }

    assert_response :success
    assert_select "turbo-frame#courses #courses_list > li", 1
    assert_select "#course_#{@published.slug}"
    assert_select "h1", 0
    assert_select "form#courses-filters", 0
    assert_select "#courses_total", text: tl("index.total", count: 1)
  end

  test "no course matching the filters shows a way to clear them; an empty catalogue says so" do
    sign_in_as create_student

    get courses_path(level: @seconde.slug)

    assert_select "#courses_empty", text: including(tl("index.no_match_title"))
    assert_select "#courses_empty a[href='#{courses_path}']", text: tl("index.clear_filters")

    Orm::Course.where(status: "published").update_all(status: "draft")
    get courses_path

    assert_select "#courses_empty", text: including(tl("index.empty_title"))
  end

  test "the colour and icon of a subject come from its category, never from its name (CA-26)" do
    create_course(name: "Analyse", level: @tle, material: create_material(name: "Mathématiques", category: "literature"))
    sign_in_as create_student

    get courses_path

    literature = ComponentsHelper::BADGE_TONES.fetch(:gold)[:chip]
    science = ComponentsHelper::BADGE_TONES.fetch(:brand)[:chip]
    assert_select "#courses_list li", text: /Analyse/ do
      assert_select "span[class*='#{literature}']", text: "Mathématiques"
    end
    assert_select "#course_#{@course.slug} span[class*='#{science}']", text: "SVT"
  end

  # ── Page d'un cours ────────────────────────────────────────────────────────

  test "a student reads a published course: breadcrumb, badges, content under KaTeX, published essential sheets" do
    meiose = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions")
    create_exercise(essential: meiose)
    create_essential(course: @course, name: "Fiche en brouillon", status: "draft")
    sign_in_as create_student

    get course_path(@course.slug)

    assert_response :success
    assert_select "title", text: tl("show.page_title", name: "Génétique et évolution")
    assert_select "nav[aria-label=?]", tl("show.breadcrumb") do
      assert_select "a[href='#{courses_path}']", text: tl("show.catalog")
      assert_select "a[href='#{courses_path(material: @svt.slug)}']", text: "SVT"
      assert_select "[aria-current=page]", text: "Génétique et évolution"
    end
    assert_select "#course_header h1", text: "Génétique et évolution"
    assert_select "#course_header", text: including("Du gène à l'espèce")
    assert_select "#course_header", text: including("Tle D")
    assert_select "#course_header", text: including("SVT")
    assert_select "#course_content [data-controller=math][data-turbo-permanent] .trix-content strong", text: "ADN"
    assert_select "#course_content", text: including("$x^2$")
    assert_select "#course_essentials li", 1
    assert_select "#course_essentials a[href='#{course_essential_path(@course.slug, meiose.slug)}']", text: "La méiose"
    assert_select "#course_essentials", text: including("Deux divisions")
    assert_select "#course_essentials", text: including(tl("essential_row.exercises", count: 1))
    assert_no_match(/Fiche en brouillon/, response.body)
    assert_select "#content_status_course_#{@course.slug}", 0
    assert_select "#course-actions-menu", 0
    assert_select "a[href='#{course_assignments_path(@course.slug)}']", 0
  end

  test "a draft or archived course, or an unknown slug, answers 404 outside the team (CA-04)" do
    [ create_student, create_teacher ].each do |user|
      sign_in_as user
      [ @draft, @archived ].each do |course|
        get course_path(course.slug)

        assert_response :not_found
        assert_no_match(including(course.name), response.body)
      end
      sign_out
    end

    sign_in_as create_student
    get course_path("inconnu")
    assert_response :not_found
  end

  test "the team reads a draft with its status panel, its draft sheets, and its actions opened in the modal" do
    create_essential(course: @draft, name: "Fiche en brouillon", status: "draft")
    sign_in_as create_team_member

    get course_path(@draft.slug)

    assert_response :success
    assert_select "#content_status_course_#{@draft.slug}", text: including(status_label(:draft)) do
      assert_select "form[action='#{publish_teams_course_path(@draft.slug)}']"
    end
    assert_select "#course-actions-menu" do
      assert_select modal_link(edit_teams_course_path(@draft.slug)), text: tl("role_actions.edit")
      assert_select modal_link(new_teams_course_essential_path(@draft.slug)), text: tl("role_actions.new_essential")
      assert_select modal_link(new_teams_import_path(kind: "essentials", course: @draft.slug)),
                    text: tl("role_actions.import_essentials")
    end
    assert_select "#course_essentials li", text: /Fiche en brouillon.*#{Regexp.escape(status_label(:draft))}/m
    assert_select "a[href='#{course_assignments_path(@draft.slug)}']", 0
  end

  test "the teacher sees « Assigner à mes classes », and no team action (CA-27)" do
    sign_in_as create_teacher

    get course_path(@course.slug)

    assert_response :success
    assert_select "#course_header a[href='#{course_assignments_path(@course.slug)}']", text: tl("role_actions.assign")
    assert_select "#course-actions-menu", 0
    assert_select "#content_status_course_#{@course.slug}", 0
    assert_select "a[href='#{edit_teams_course_path(@course.slug)}']", 0
  end

  test "a school staff member reads the catalogue and a published course, without any action" do
    sign_in_as create_user(role: "school_admin")

    get courses_path
    assert_response :success

    get course_path(@course.slug)
    assert_response :success
    assert_select "#course-actions-menu", 0
    assert_select "a[href='#{course_assignments_path(@course.slug)}']", 0
  end

  test "a course without essential sheet nor content shows the empty state and no content section" do
    bare = create_course(name: "Cours vide", content: nil)
    sign_in_as create_student

    get course_path(bare.slug)

    assert_select "#course_essentials", text: including(tl("show.empty"))
    assert_select "#course_content", 0
  end

  test "the content is sanitised on render: no script tag, no event attribute, no javascript link (CA-04)" do
    Orm::Course.find(@course.id).update!(
      content: "<p onclick=\"alert(1)\">Texte <strong>gras</strong></p><script>alert(2)</script><a href=\"javascript:alert(3)\">lien</a>"
    )
    sign_in_as create_student

    get course_path(@course.slug)

    assert_select "#course_content strong", text: "gras"
    assert_no_match(/<script>alert|onclick|javascript:alert/, response.body)
  end

  test "no page loads a script or a stylesheet from a third-party host (TR-41)" do
    sign_in_as create_team_member

    [ courses_path, course_path(@course.slug) ].each do |path|
      get path

      assert_select "script[src^=http], link[rel=stylesheet][href^=http]", 0
    end
  end
end
