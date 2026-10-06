require "test_helper"

# CA-01, CA-04, CA-10, CA-26, CA-27, TR-41 — UDR-0013. Le catalogue et la page d'un cours, pour tous les rôles connectés.
# L'ancienne application ignorait les filtres, laissait lire un brouillon par URL directe, colorait la matière d'après
# son nom, et n'affichait jamais « Assigner à mes classes ». Ici : filtres par slug, 404 hors équipe pour tout cours non
# publié, couleur tirée de la catégorie, points d'entrée de l'équipe en modale. ADR-0072, UDR-0013 (amendée le
# 2026-10-02) : un cours ne s'assigne plus ; l'enseignant lit la page sans action, et l'ancien écran répond 404.
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
  # L'ancien écran « Assigner un cours » (UDR-0030, dépréciée) : sa route n'existe plus.
  def assignments_href(slug) = "/courses/#{slug}/assignments"

  test "a visitor is sent to the sign-in" do
    get courses_path
    assert_redirected_to new_session_path

    get course_path(@course.slug)
    assert_redirected_to new_session_path
  end

  # ── Catalogue ──────────────────────────────────────────────────────────────

  test "a student sees the published courses only, as cards, without team actions nor status" do
    sign_in_as create_student_for(@course)

    get courses_path

    assert_response :success
    assert_select "title", text: "#{tl("index.page_title")} · Élève · Lnclass"
    assert_select "h1", text: tl("index.title")
    assert_select "turbo-frame#courses[data-turbo-action=advance][target=_top] #courses_list > li", 2
    assert_select "#courses_list li:first-child", text: /Philosophie.*La conscience/m
    assert_select "#course_#{@course.slug} a[href='#{course_path(@course.slug)}']" do
      assert_select "*", text: including("SVT")
      # UDR-0013, amendement du 2026-10-02 : l'élève ne voit que son niveau ; le badge de niveau quitte ses cartes.
      assert_select "*", text: including("Tle D"), count: 0
      assert_select "h2", text: "Génétique et évolution"
      assert_select "*", text: including("Du gène à l'espèce")
      # UDR-0013, amendement du 2026-10-05 ter : le pied « Ouvrir le cours → » est rétabli.
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
    # UDR-0013, amendement du 2026-10-05 : « Publié », l'état normal, n'est plus écrit sur la carte.
    assert_select "#course_#{@course.slug}", text: including(status_label(:published)), count: 0
    assert_select "#course_#{@course.slug} h2", text: "Génétique et évolution"
    assert_select modal_link(new_teams_course_path), text: tl("index.new_course")
    assert_select modal_link(new_teams_import_path(kind: "course_tree")), text: tl("index.import")
  end

  test "the filters list the levels and materials, and keep the chosen ones" do
    # Tous les niveaux et toutes les matières : l'équipe (l'élève voit son niveau, l'enseignant ses classes, UDR-0077 §3.2).
    sign_in_as create_team_member

    get courses_path(material: @svt.slug)

    assert_select "form#courses-filters[method=get][action='#{courses_path}'][data-turbo-frame=courses][data-turbo-action=advance]" do
      assert_select "select[name=level] option", 3
      assert_select "select[name=level] option[value='#{@tle.slug}']", text: "Tle"
      assert_select "select[name=material] option[selected][value='#{@svt.slug}']", text: "SVT"
    end
    assert_select "#courses_list > li", 3
    assert_select "#course_#{@course.slug}"
  end

  # RE-14 (UDR-0069 §3.3, §3.4) : l'adresse d'une bulle « Tle D » de l'accueil enseignant.
  test "a « Tle D » bubble lists the subject's Tle courses without series and in Tle D, neither Tle C nor another subject" do
    maths = create_material(name: "Mathématiques")
    d = @course.series
    common = create_course(name: "Analyse", level: @tle, material: maths)
    own = create_course(name: "Probabilités", level: @tle, series: d, material: maths)
    other_series = create_course(name: "Arithmétique", level: @tle, series: create_series(name: "C"), material: maths)
    other_subject = create_course(name: "Mécanique", level: @tle, series: d, material: create_material(name: "Physique-Chimie"))
    link_level_series(level: @tle, series: d)

    [ create_teacher(material: maths, classrooms: [ create_classroom(level: @tle, series: d) ]), create_team_member ].each do |user|
      sign_in_as user

      get courses_path(level: "tle", series: "d", material: "mathematiques")

      assert_response :success
      assert_select "#courses_list > li", 2
      assert_select "#course_#{common.slug}"
      assert_select "#course_#{own.slug}"
      assert_select "#course_#{other_series.slug}", 0
      assert_select "#course_#{other_subject.slug}", 0
      assert_select "select[name=series] option[selected][value=d]", text: "D"
      sign_out
    end
  end

  test "the team chooses a « Série » between « Niveau » and « Matière »; the student has no such list" do
    c = create_series(name: "C")
    link_level_series(level: @tle, series: @course.series)
    link_level_series(level: @tle, series: c)
    link_level_series(level: create_level(name: "1ère"), series: c)

    [ create_team_member ].each do |user|
      sign_in_as user

      get courses_path

      assert_select "form#courses-filters.lg\\:grid-cols-4" do
        assert_select "div.sm\\:col-span-2.lg\\:col-span-4 input[name=q]"
        assert_equal %w[level series material], css_select("select").map { it["name"] }
        assert_select "label[for=filter_series]", text: tl("index.filters.series")
        assert_select "select#filter_series[name=series][data-action='change->search#submit'] option", 3
        assert_select "select[name=series] option:nth-child(1)[value='']", text: tl("index.filters.all_series")
        assert_select "select[name=series] option:nth-child(2)[value=c]", text: "C"
        assert_select "select[name=series] option:nth-child(3)[value=d]", text: "D"
      end
      sign_out
    end

    sign_in_as create_student_for(@course)
    get courses_path

    assert_equal %w[material], css_select("form#courses-filters select").map { it["name"] }
    assert_select "label[for=filter_series]", 0
  end

  test "a series in the address only narrows a student's catalogue, never widens it" do
    create_course(name: "Mécanique", level: @tle, series: create_series(name: "C"), material: @svt)
    sign_in_as create_student_for(@course)

    get courses_path(level: @tle.slug, series: "c")

    assert_select "#courses_list > li", 1
    assert_select "#course_#{@published.slug}"
  end

  test "the filters form searches while typing: a « q » search field, lists sent on change, « Filtrer » kept without JS (FU-47)" do
    # Le filtre par niveau et la recherche dans tous les niveaux : l'équipe (UDR-0077 §3.2).
    sign_in_as create_team_member

    get courses_path(q: "généti")

    assert_select "form#courses-filters[role=search][aria-label=?][data-controller=search]", tl("index.filters.label") do
      assert_select "label[for=q]", text: tl("index.filters.search")
      assert_select "input[type=search][name=q][id=q][value='généti'][autocomplete=off][data-action='search#queue']"
      assert_select "select[name=level][data-action='change->search#submit']"
      assert_select "select[name=material][data-action='change->search#submit']"
      # UDR-0077, amendement du 2026-10-06 : la cellule de « Filtrer » est la cible, cachée entière avec JavaScript ;
      # plus d'« Effacer » dans le formulaire.
      assert_select "div[data-search-target=button] button[type=submit]", text: tl("index.filters.submit")
      assert_select "a[href='#{courses_path}']", 0
    end
    assert_select "turbo-frame#courses.transition-opacity.aria-busy\\:opacity-50"
    assert_select "#courses_list > li", 1
    assert_select "#course_#{@course.slug}"
    assert_select "#courses_total[aria-live=polite]", text: tl("index.total", count: 1)
  end

  test "the search ignores case and accents, and combines with the filters (FU-47)" do
    create_course(name: "Mathématiques 3e", level: @seconde, material: @philo)
    # Le filtre par niveau et la recherche dans tous les niveaux : l'équipe (UDR-0077 §3.2).
    sign_in_as create_team_member

    get courses_path(q: "MATHEMATIQUES"), headers: { "Turbo-Frame" => "courses" }
    assert_select "#courses_list > li", 1
    assert_select "#courses_list", text: including("Mathématiques 3e")

    get courses_path(q: "mathematiques", level: @tle.slug), headers: { "Turbo-Frame" => "courses" }
    assert_select "#courses_list", 0
  end

  test "no course matching the search offers « Effacer la recherche » (FU-47)" do
    sign_in_as create_student_for(@course)

    get courses_path(q: "zzz"), headers: { "Turbo-Frame" => "courses" }

    assert_select "#courses_total", text: tl("index.total", count: 0)
    assert_select "#courses_empty", text: including(tl("index.no_match_title"))
    assert_select "#courses_empty a[href='#{courses_path}']", text: tl("index.clear_search")
  end

  test "a request from the courses frame receives the frame only, filtered" do
    sign_in_as create_student_for(@course)

    get courses_path(level: @tle.slug, material: @philo.slug), headers: { "Turbo-Frame" => "courses" }

    assert_response :success
    assert_select "turbo-frame#courses #courses_list > li", 1
    assert_select "#course_#{@published.slug}"
    assert_select "h1", 0
    assert_select "form#courses-filters", 0
    assert_select "#courses_total", text: tl("index.total", count: 1)
  end

  test "no course matching the filters shows a way to clear them; an empty catalogue says so" do
    sign_in_as create_student_for(@course)

    get courses_path(level: @seconde.slug)

    assert_select "#courses_empty", text: including(tl("index.no_match_title"))
    assert_select "#courses_empty a[href='#{courses_path}']", text: tl("index.clear_search")

    Orm::Course.where(status: "published").update_all(status: "draft")
    get courses_path

    assert_select "#courses_empty", text: including(tl("index.empty_title"))
  end

  # UDR-0013, amendement du 2026-10-02 (UDR-0057), décision du porteur : élève seulement. Amendement du 2026-10-05 ter :
  # la carte garde le badge de la matière filtrée, et son pied « Ouvrir le cours → ».
  test "a student's catalogue has no subtitle but an info tip, and its cards keep the filtered subject" do
    sign_in_as create_student_for(@course)

    get courses_path(material: @svt.slug)

    assert_select "h1", text: tl("index.title")
    assert_no_match(including(tl("index.subtitle")), response.body)
    assert_select "#main details", text: including(tl("index.student_scope")) do
      assert_select "summary", text: including(tl("index.student_scope_label"))
    end
    assert_select "#course_#{@course.slug}" do
      assert_select "h2", text: "Génétique et évolution"
      assert_select "div.mb-4 > span", 1
      assert_select "div.mb-4 > span", text: "SVT"
      assert_select "*", text: including("Tle"), count: 0
      assert_select "div.border-t", text: including(tl("course_card.open"))
    end

    get courses_path(material: @philo.slug, q: "zzz"), headers: { "Turbo-Frame" => "courses" }
    assert_select "#courses_empty", text: including(tl("index.student_no_match_description"))
  end

  test "the team's catalogue is unchanged: subtitle, level badge, subject badge even when filtered" do
    [ create_team_member ].each do |user|
      sign_in_as user

      get courses_path(material: @svt.slug)

      assert_select "#main", text: including(tl("index.subtitle"))
      assert_select "#main details", 0
      assert_select "#course_#{@course.slug} div.mb-4" do
        assert_select "*", text: including("SVT")
        assert_select "*", text: including("Tle D")
      end

      get courses_path(q: "zzz"), headers: { "Turbo-Frame" => "courses" }
      assert_select "#courses_empty", text: including(tl("index.no_match_description"))
      sign_out
    end
  end

  # ── Catalogue de l'enseignant et téléphone (UDR-0077 §3.2) ───────────────

  test "CA-5: the teacher sees their subject at the levels and series of their classrooms, nothing else" do
    maths = create_material(name: "Mathématiques")
    d = @course.series
    own = create_course(name: "Probabilités", level: @tle, series: d, material: maths)
    common = create_course(name: "Analyse", level: @tle, material: maths)
    other_series = create_course(name: "Arithmétique", level: @tle, series: create_series(name: "C"), material: maths)
    other_level = create_course(name: "Calcul littéral", level: @seconde, material: maths)
    other_subject = create_course(name: "Mécanique", level: @tle, series: d, material: create_material(name: "Physique-Chimie"))
    link_level_series(level: @tle, series: d)
    sign_in_as create_teacher(material: maths, classrooms: [ create_classroom(level: @tle, series: d) ])

    get courses_path

    assert_equal [ "course_#{common.slug}", "course_#{own.slug}" ], css_select("#courses_list > li").map { it["id"] }
    [ other_series, other_level, other_subject ].each { assert_select "#course_#{it.slug}", 0 }
    assert_select "#main", text: including(tl("index.teacher_subtitle", material: "Mathématiques"))
    assert_select "form#courses-filters" do
      assert_equal %w[level series], css_select("select").map { it["name"] }
      assert_equal [ "", "tle" ], css_select("select[name=level] option").map { it["value"] }
      assert_equal [ "", "d" ], css_select("select[name=series] option").map { it["value"] }
    end
    # UDR-0013, amendement du 2026-10-05 (ter) : le badge de matière reste sur chaque carte, pour tous les rôles.
    assert_select "#course_#{own.slug} div.mb-4", text: including("Mathématiques")
    assert_select "#course_#{own.slug} div.mb-4", text: including("Tle D")
  end

  test "CA-5: a draft or archived course of the teacher's subject and levels stays out of their catalogue" do
    draft = create_course(name: "Brouillon SVT", level: @tle, series: @course.series, material: @svt, status: "draft")
    archived = create_course(name: "Archivé SVT", level: @tle, series: @course.series, material: @svt, status: "archived")
    sign_in_as create_teacher(material: @svt, classrooms: [ create_classroom(level: @tle, series: @course.series) ])

    get courses_path

    assert_select "#course_#{@course.slug}"
    [ draft, archived ].each { assert_select "#course_#{it.slug}", 0 }
  end

  test "CA-5: a teacher without a classroom this year sees no course, and is invited to declare their classrooms" do
    sign_in_as create_teacher(material: @svt)

    get courses_path

    assert_select "#courses_list", 0
    assert_select "#courses_empty", text: including(tl("index.teacher_no_class_title")) do
      assert_select "a[href='#{teacher_classrooms_path}']", text: tl("index.teacher_no_class_action")
    end
  end

  # UDR-0077, amendement du 2026-10-06 (décision du porteur) : les filtres s'affichent aussi sur téléphone ; « Tout voir »,
  # dans le frame, quitte les filtres à toutes les largeurs.
  test "CA-6: the search and filters show on a phone too, for every role; a filtered list offers « Tout voir » at every width" do
    teacher = create_teacher(material: @svt, classrooms: [ create_classroom(level: @tle, series: @course.series) ])
    [ create_student_for(@course), teacher, create_team_member ].each do |user|
      sign_in_as user

      get courses_path

      assert_select "form#courses-filters.grid"
      assert_select "form#courses-filters.hidden", 0
      assert_select "#courses_reset", 0

      get courses_path(material: @svt.slug)

      assert_select "turbo-frame#courses #courses_reset.min-h-tap[href='#{courses_path}']", text: tl("index.reset")
      assert_select "#courses_reset.sm\\:hidden", 0
      sign_out
    end
  end

  test "the colour and icon of a subject come from its category, never from its name (CA-26)" do
    create_course(name: "Analyse", level: @tle, material: create_material(name: "Mathématiques", category: "literature"))
    sign_in_as create_student_for(@course)

    get courses_path

    literature = ComponentsHelper::BADGE_TONES.fetch(:gold)[:chip]
    science = ComponentsHelper::BADGE_TONES.fetch(:brand)[:chip]
    assert_select "#courses_list li", text: /Analyse/ do
      assert_select "span[class*='#{literature}']", text: "Mathématiques"
    end
    assert_select "#course_#{@course.slug} span[class*='#{science}']", text: "SVT"
  end

  # ── Page d'un cours ────────────────────────────────────────────────────────

  test "a student reads a published course: back link, badges, content under KaTeX, published essential sheets" do
    meiose = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions")
    create_exercise(essential: meiose)
    create_essential(course: @course, name: "Fiche en brouillon", status: "draft")
    sign_in_as create_student_for(@course)

    get course_path(@course.slug)

    assert_response :success
    assert_select "title", text: "Génétique et évolution · Élève · Lnclass"
    # FU-14 : le seul retour est « Cours », vers le catalogue ; le fil complet a disparu.
    assert_select "main nav", 1
    assert_select "nav[aria-label=?] a[href='#{courses_path}']", I18n.t("components.back_link.label"), text: tl("show.back")
    assert_no_match(/href="#{Regexp.escape(courses_path)}\?material=/, response.body)
    assert_select "main [aria-current=page]", 0
    assert_select "#course_header h1", text: "Génétique et évolution"
    assert_select "#course_header", text: including("Du gène à l'espèce")
    assert_select "#course_header", text: including("Tle D")
    assert_select "#course_header", text: including("SVT")
    assert_select "#course_content [data-controller=math][data-turbo-permanent] .trix-content strong", text: "ADN"
    assert_select "#course_content", text: including("$x^2$")
    assert_select "#course_essentials li", 1
    assert_select "#course_essentials a[href='#{course_essential_path(@course.slug, meiose.slug)}']", text: "La méiose"
    assert_select "#course_essentials", text: including("Deux divisions")
    # Épuration (2026-09-30) : « Essentielles de la leçon », sans le nombre d'exercices de chaque fiche.
    assert_select "#course_essentials_title", text: "Essentielles de la leçon"
    assert_select "#course_essentials", text: /exercice/, count: 0
    assert_no_match(/Fiche en brouillon/, response.body)
    assert_select "#content_status_course_#{@course.slug}", 0
    assert_select "#course-actions-menu", 0
    assert_select "a[href='#{assignments_href(@course.slug)}']", 0
  end

  # UDR-0013, amendement du 2026-10-02 (UDR-0057) : 3 fiches, puis « Voir plus » ; chaque ligne est un lien étiré.
  test "a student sees 3 sheets then « Voir plus », each row a stretched link without status" do
    sheets = %w[Méiose Mitose Mutations Hérédité].map { create_essential(course: @course, name: it, subtitle: "Sous-titre") }
    sign_in_as create_student_for(@course)

    get course_path(@course.slug)

    assert_select "#course_essentials [data-controller=reveal]" do
      assert_select "li", 4
      assert_select "li[hidden]", 1
      assert_select "li[data-reveal-target=item]", 4
      assert_select "#essential_#{sheets.last.slug}[hidden]"
      assert_select "button[data-action='reveal#more']", text: I18n.t("components.reveal.more")
      assert_select "[role=status][aria-live=polite]"
    end
    assert_select "#essential_#{sheets.first.slug}.relative.active\\:bg-mist" do
      assert_select "a.after\\:absolute.after\\:inset-0.line-clamp-2[href='#{course_essential_path(@course.slug, sheets.first.slug)}']",
                    text: "Méiose"
      assert_select "p.line-clamp-2", text: "Sous-titre"
      assert_select "svg[aria-hidden=true]"
    end
  end

  test "the teacher and the team keep the full list of sheets, without « Voir plus », in the current row" do
    %w[Méiose Mitose Mutations Hérédité].each { create_essential(course: @course, name: it) }

    [ create_teacher, create_team_member ].each do |user|
      sign_in_as user

      get course_path(@course.slug)

      assert_select "#course_essentials li", 4
      assert_select "#course_essentials li[hidden]", 0
      assert_select "#course_essentials [data-controller=reveal]", 0
      assert_select "#course_essentials li.sm\\:flex-row", 4
      sign_out
    end
  end

  test "a draft or archived course, or an unknown slug, answers 404 outside the team (CA-04)" do
    [ create_student_for(@course), create_teacher ].each do |user|
      sign_in_as user
      [ @draft, @archived ].each do |course|
        get course_path(course.slug)

        assert_response :not_found
        assert_no_match(including(course.name), response.body)
      end
      sign_out
    end

    sign_in_as create_student_for(@course)
    get course_path("inconnu")
    assert_response :not_found
  end

  test "the team reads a draft with its status panel, its draft sheets, and its actions opened in the modal" do
    create_essential(course: @draft, name: "Fiche en brouillon", status: "draft")
    sign_in_as create_team_member

    get course_path(@draft.slug)

    assert_response :success
    assert_select "#content_status_course_#{@draft.slug}", text: including(status_label(:draft)) do
      assert_select "form, a", 0
    end
    assert_select "#course-actions-menu" do
      assert_select "a[role=menuitem][data-turbo-method=patch][href='#{publish_teams_course_path(@draft.slug)}']"
      assert_select "a[role=menuitem][data-turbo-method=patch][href='#{publish_all_teams_course_path(@draft.slug)}']",
                    text: I18n.t("catalog.content_status.actions.publish_all")
      assert_select modal_link(edit_teams_course_path(@draft.slug)), text: tl("role_actions.edit")
      assert_select modal_link(new_teams_course_essential_path(@draft.slug)), text: tl("role_actions.new_essential")
      assert_select modal_link(new_teams_import_path(kind: "essentials", course: @draft.slug)),
                    text: tl("role_actions.import_essentials")
    end
    assert_select "#course_essentials li", text: /Fiche en brouillon.*#{Regexp.escape(status_label(:draft))}/m
    assert_select "a[href='#{assignments_href(@draft.slug)}']", 0
  end

  test "the teacher reads the course without any action: no « Assigner à mes classes », no team action (ADR-0072)" do
    sign_in_as create_teacher

    get course_path(@course.slug)

    assert_response :success
    assert_select "a[href='#{assignments_href(@course.slug)}']", 0
    assert_select "#course_header a, #course_header button", text: /Assigner/, count: 0
    assert_no_match(/Assigner/, response.body)
    assert_select "#course-actions-menu", 0
    assert_select "#content_status_course_#{@course.slug}", 0
    assert_select "a[href='#{edit_teams_course_path(@course.slug)}']", 0
  end

  test "the former « Assigner un cours » screen answers 404, for every role (UDR-0030, deprecated)" do
    get assignments_href(@course.slug)
    assert_response :not_found

    [ create_teacher, create_team_member, create_student_for(@course) ].each do |user|
      sign_in_as user

      get assignments_href(@course.slug)

      assert_response :not_found
      assert_no_match "Génétique et évolution", response.body
      sign_out
    end
    assert_not Rails.application.routes.url_helpers.respond_to?(:course_assignments_path)
  end

  test "a school staff member reads the catalogue and a published course, without any action" do
    sign_in_as create_user(role: "school_admin")

    get courses_path
    assert_response :success

    get course_path(@course.slug)
    assert_response :success
    assert_select "#course-actions-menu", 0
    assert_select "a[href='#{assignments_href(@course.slug)}']", 0
  end

  test "a course without essential sheet nor content shows the empty state and no content section" do
    bare = create_course(name: "Cours vide", content: nil)
    sign_in_as create_student_for(bare)

    get course_path(bare.slug)

    assert_select "#course_essentials", text: including(tl("show.empty"))
    assert_select "#course_content", 0
  end

  test "the content is sanitised on render: no script tag, no event attribute, no javascript link (CA-04)" do
    Orm::Course.find(@course.id).update!(
      content: "<p onclick=\"alert(1)\">Texte <strong>gras</strong></p><script>alert(2)</script><a href=\"javascript:alert(3)\">lien</a>"
    )
    sign_in_as create_student_for(@course)

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

  # Chantier politique-cache, lot E (ADR-0067) : les icônes des cartes (matière, flèche) sont dessinées une fois, dans le
  # frame « courses » qu'une recherche ou un filtre remplace seul.
  test "the cards take their icons from symbols drawn once in the courses frame" do
    sign_in_as create_team_member

    get courses_path
    assert_icons_drawn_once "turbo-frame#courses"

    get courses_path(material: @svt.slug), headers: { "Turbo-Frame" => "courses" }
    assert_icons_drawn_once "turbo-frame#courses"
  end

  # Lot E4 (chantier politique-cache), UDR-0013 amendement du 2026-10-05 : 24 cartes par page ; au bas, un frame différé
  # demande la suivante (filtres gardés) et ne reçoit que ses cartes et le frame d'après ; sans JavaScript, son bouton
  # ouvre la page suivante entière. Le compte annonce tous les cours.
  test "the catalog shows 24 cards, then loads the next page in a lazy frame; the filters ride along" do
    25.times { |index| create_course(name: format("Cours %02d", index), level: @seconde, material: @svt) }
    sign_in_as create_team_member
    next_path = courses_path(material: @svt.slug, page: 2)

    get courses_path(material: @svt.slug)

    assert_select "#courses_total", text: tl("index.total", count: 28)
    assert_select "#courses_list > li", 24
    assert_select "turbo-frame#courses_page_2[loading=lazy][target=_top][src='#{next_path}']" do
      assert_select "a[href='#{next_path}'][data-turbo-frame=courses_page_2]", text: tl("page.more")
    end
    assert_icons_drawn_once "turbo-frame#courses"

    get next_path, headers: { "Turbo-Frame" => "courses_page_2" }

    assert_response :success
    assert_match(/\A\s*<turbo-frame id="courses_page_2" target="_top">/, response.body)
    assert_no_match(/<html|<main|courses-filters|courses_total/, response.body)
    assert_select "ul#courses_list_page_2.mt-5 > li", 4
    assert_select "turbo-frame#courses_page_3", 0
    assert_icons_drawn_once "turbo-frame#courses_page_2"
    assert_select "symbol[id^='courses-page-2-icon-']", minimum: 1

    get next_path

    assert_response :success
    assert_select "main#main #courses_list > li", 4
    assert_select "#courses_total", text: tl("index.total", count: 28)
  end
end
