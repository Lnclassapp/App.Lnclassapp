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

  # ADR-0103 §4.6: no list in the current school (a rejected request lost to the migration, then nothing inherited).
  test "a teacher without any subject in the current school is invited to choose them, with no broken subtitle" do
    teacher = create_teacher(school: create_school, classrooms: [ create_classroom(level: @tle) ])
    Orm::TeacherSchoolMaterial.where(teacher_id: teacher.id).delete_all
    sign_in_as teacher

    get courses_path

    assert_response :success
    assert_select "#main", text: /Les cours de ,/, count: 0
    assert_select "#courses_material_chips", 0
    assert_select "#courses_empty", text: including(tl("index.teacher_no_material_title"))
    assert_select "#courses_empty #{modal_link(edit_profile_materials_path)}"
  end

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
    assert_select "turbo-frame#courses[data-turbo-action=advance][target=_top] #courses_groups li", 2
    # CA-1 (UDR-0085 §3.2, ADR-0090 §4.2) : un groupe par matière, dans l'ordre du programme, SVT (3) avant Philosophie (7).
    assert_equal %w[courses_group_svt courses_group_philosophie], css_select("#courses_groups > section").map { it["id"] }
    # UDR-0085 §3.4 : sous 640 px, ses cartes restent dans la marge, arrondies (exception à UDR-0005).
    assert_select "#courses_groups[data-bleed-keep]"
    assert_select "section#courses_group_svt[aria-labelledby=courses_group_svt_title] h2#courses_group_svt_title" do
      assert_select "a[href='#{courses_path(material: @svt.slug)}'][aria-label='#{tl("course_group_title.label", material: "SVT", count: 1)}']" do
        assert_select "img[src*='subjects/svt']"
        assert_select "span", text: "SVT"
        assert_select "span", text: tl("course_group_title.count", count: 1)
      end
    end
    # CA-E6 (UDR écrans élève §3.6) : une ligne entière cliquable, d'au moins 44 px, sans « Commencer la fiche de cours ».
    assert_select "#course_#{@course.slug} a.min-h-tap[href='#{course_path(@course.slug)}']" do
      assert_select "*", text: including("SVT"), count: 0
      assert_select "*", text: including("Tle D"), count: 0
      assert_select "span", text: "Génétique et évolution"
      assert_select "p", text: including("Du gène à l'espèce")
      assert_select "*", text: including(tl("course_card.open")), count: 0
    end
    assert_no_match(/Brouillon de cours|Cours archivé/, response.body)
    assert_no_match(including(status_label(:published)), response.body)
    assert_select "a[href='#{new_teams_course_path}']", 0
    assert_select "a[href^='#{new_teams_import_path}']", 0
  end

  # UDR-0130 §2 : la rubrique garde son nom court « Cours » ; le compteur nomme l'objet, « fiches de cours ».
  test "a student opens the « Cours » tab and reads « 3 fiches de cours »" do
    create_course(name: "Thalès", level: @tle, material: create_material(name: "Mathématiques"))
    sign_in_as create_student_for(@course)

    get courses_path

    assert_response :success
    assert_select "a[href='#{courses_path}'][aria-current=page]", text: "Cours"
    assert_select "h1", text: "Cours"
    assert_select "#courses_total", text: "3 fiches de cours · #{tl("index.student_progression")}"
  end

  # CA-E6 : « Progression DPFC » est écrit une fois, sous la recherche ; la ligne d'une fiche ne garde que la leçon.
  test "CA-E6: a student reads « Progression DPFC » once, each row keeps its lesson only, in one card per subject" do
    create_course(name: "Limites et continuité", subtitle: "Leçon 1 · Progression DPFC 2026-2027", level: @tle,
                  material: create_material(name: "Mathématiques"))
    @course.update!(subtitle: "Progression DPFC 2026-2027 · Leçon 3")
    sign_in_as create_student_for(@course)

    get courses_path

    # Une fois sur téléphone ; le bloc ordinateur (masqué sous lg) l'écrit une fois aussi, sous « N leçons ».
    assert_equal 1, css_select("#student_courses > :first-child").to_s.scan("Progression DPFC").size
    assert_equal 1, css_select("#student_lessons").to_s.scan("Progression DPFC").size
    assert_select "#courses_total", text: including(tl("index.student_progression"))
    assert_select "li#course_#{@course.slug} a p", text: "Leçon 3"
    assert_select "li a p", text: "Leçon 1"
    assert_select "#courses_groups > section", 3
    assert_select "#courses_groups > section > ul.divide-y", 3
    assert_select "#courses_groups li", 3
    assert_no_match(/Commencer la fiche de cours|Reprendre la fiche de cours|Revoir la fiche de cours/, response.body)
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

    # L'enseignant a ses propres tests plus bas (CA-G5, CA-N1) : sans menus, avec des cartes qui portent leurs fiches.
    sign_in_as create_team_member

    get courses_path(level: "tle", series: "d", material: "mathematiques")

    assert_response :success
    assert_select "#courses_list > li", 2
    assert_select "#course_#{common.slug}"
    assert_select "#course_#{own.slug}"
    assert_select "#course_#{other_series.slug}", 0
    assert_select "#course_#{other_subject.slug}", 0
    assert_select "select[name=series] option[selected][value=d]", text: "D"
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

    # CA-2 (UDR-0085 §3.1) : l'élève n'a plus que la recherche.
    assert_empty css_select("form#courses-filters select")
    assert_select "form#courses-filters input[type=search][name=q]"
  end

  test "a series in the address only narrows a student's catalogue, never widens it" do
    create_course(name: "Mécanique", level: @tle, series: create_series(name: "C"), material: @svt)
    sign_in_as create_student_for(@course)

    get courses_path(level: @tle.slug, series: "c")

    assert_select "#courses_groups li", 1
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
    assert_select "#courses_total[aria-live=polite]", text: including(tl("index.total", count: 1))
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

    assert_select "#courses_total", text: including(tl("index.total", count: 0))
    assert_select "#courses_empty", text: including(tl("index.no_match_title"))
    # CA-5 (UDR-0085 §3.5)
    assert_select "#courses_empty", text: including(tl("index.student_no_match_description"))
    assert_select "#courses_empty a[href='#{courses_path}']", text: tl("index.clear_search")
  end

  test "a request from the courses frame receives the frame only, filtered" do
    sign_in_as create_student_for(@course)

    get courses_path(level: @tle.slug, material: @philo.slug), headers: { "Turbo-Frame" => "courses" }

    assert_response :success
    assert_select "turbo-frame#courses #courses_groups li", 1
    assert_select "#course_#{@published.slug}"
    assert_select "h1", 0
    assert_select "form#courses-filters", 0
    assert_select "#courses_total", text: including(tl("index.total", count: 1))
  end

  test "no course matching the filters shows a way to clear them; an empty catalogue says so" do
    sign_in_as create_student_for(@course)

    get courses_path(level: @seconde.slug)

    assert_select "#courses_empty", text: including(tl("index.no_match_title"))
    assert_select "#courses_empty a[href='#{courses_path}']", text: tl("index.clear_search")

    Orm::Course.where(status: "published").update_all(status: "draft")
    get courses_path

    assert_select "#courses_empty", text: including("Aucune fiche de cours pour l'instant")
  end

  # UDR-0013, amendement du 2026-10-02 (UDR-0057) : pas de sous-titre, une infobulle. CA-13, CA-14 (UDR-0085 §3.1) : la
  # vue d'une matière (l'adresse des bulles « Mes matières ») porte son icône et son nom, sans lien « Tous les cours » ni
  # titre de groupe ; la recherche y reste limitée à la matière.
  test "CA-13: a student's catalogue has an info tip; the view of a subject is titled by the subject, search kept inside it" do
    create_course(name: "Mitose", level: @tle, material: @svt)
    sign_in_as create_student_for(@course)

    get courses_path
    assert_select "h1", text: tl("index.title")
    assert_no_match(including(tl("index.subtitle")), response.body)
    assert_select "#main details", text: including(tl("index.student_scope")) do
      assert_select "summary", text: including(tl("index.student_scope_label"))
    end

    get courses_path(material: @svt.slug)

    assert_select "title", text: "SVT · Élève · Lnclass"
    assert_select "#courses_material_title" do
      assert_select "img[src*='subjects/svt']"
      assert_select "h1", text: "SVT"
    end
    assert_select "#main details", 0
    assert_select "form#courses-filters input[type=hidden][name=material][value='#{@svt.slug}']"
    assert_select "#courses_groups h2", 0
    assert_select "#courses_groups li", 2
    assert_select "#course_#{@published.slug}", 0
    assert_select "a[href='#{courses_path}']", text: /Tous les cours/, count: 0
    assert_select "#courses_reset", 0

    get courses_path(material: @svt.slug, q: "mito"), headers: { "Turbo-Frame" => "courses" }
    assert_select "#courses_groups li", 1
    assert_select "#courses_reset[href='#{courses_path(material: @svt.slug)}']", text: tl("index.reset")

    get courses_path(material: @philo.slug, q: "zzz"), headers: { "Turbo-Frame" => "courses" }
    assert_select "#courses_empty", text: including(tl("index.student_no_match_description"))
    assert_select "#courses_empty a[href='#{courses_path(material: @philo.slug)}']", text: tl("index.clear_search")
  end

  # CA-3 (UDR-0085 §2) : une lecture d'élève en base ne change rien pour l'enseignant ni pour l'équipe.
  test "CA-3: with a student's read in base, the teacher and the team keep « Ouvrir le cours », without any progress" do
    create_essential_read(student: create_student_for(@course), essential: create_essential(course: @course))
    teacher = create_teacher(material: @svt, classrooms: [ create_classroom(level: @tle, series: @course.series) ])

    [ teacher, create_team_member ].each do |user|
      sign_in_as user
      get courses_path

      # La carte de l'enseignant n'a plus de pied « Ouvrir la fiche de cours » (UDR enseignant §3.7) ; l'équipe le garde.
      assert_select "#course_#{@course.slug}", text: including(tl("course_card.open")) unless user == teacher
      %w[started done].each { assert_no_match(including(tl("course_card.progress.#{it}")), response.body) }
      assert_select "#courses_groups", 0
      assert_select "#courses_list svg.text-success", 0
      sign_out
    end
  end

  def queries_of(path)
    get path
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    count
  end

  # PRD §7 : le nombre de requêtes de la page ne dépend ni du nombre de cours ni des lectures. Au plus 18 : Lot O5 y ajoute
  # les matières de l'élève (1) et les leçons de la matière avec leurs fiches (4), lues pour l'ordinateur.
  test "GET /courses as a student: the same number of queries for 2 courses and for 25 courses with reads, at most 18" do
    student = create_student_for(@course)
    sign_in_as student
    paths = [ courses_path, courses_path(q: "e"), courses_path(material: @svt.slug) ]
    few = paths.map { queries_of(it) }

    23.times do |index|
      course = create_course(name: "Cours #{index}", level: @tle, material: @svt)
      create_essential_read(student:, essential: create_essential(course:))
    end
    many = paths.map { queries_of(it) }

    assert_equal few, many
    assert(many.all? { it <= 18 }, many.inspect)
  end

  test "an unknown subject in the student's address gives the « Cours » title and no course, never an error" do
    sign_in_as create_student_for(@course)

    get courses_path(material: "inconnue", page: 2, after_material: [ "x" ])

    assert_response :success
    assert_select "h1", text: tl("index.title")
    assert_select "#courses_material_title", 0
    assert_select "#courses_empty", text: including(tl("index.empty_title"))
  end

  # UDR-0085 §3.1 : l'élève revient par le menu (avatar, menu de gauche), plus par un lien « Accueil » ; l'équipe n'en a pas.
  test "neither the student's catalogue nor the team's has a back link" do
    [ create_student_for(@course), create_team_member ].each do |user|
      sign_in_as user
      [ courses_path, courses_path(material: @svt.slug) ].each do |path|
        get path

        assert_select "nav[aria-label=?]", I18n.t("components.back_link.label"), 0
      end
      sign_out
    end
  end

  # CA-E6 : la ligne dit où en est l'élève par la pastille « En cours » ; « Reprendre » rouvre toujours la dernière fiche lue
  # (sans préchargement, qui la servirait sans l'ouvrir) ; une fiche de cours finie porte la coche verte.
  test "CA-E6: the row carries « En cours » (last sheet read, no prefetch), or the green check once done" do
    student = create_student_for(@course)
    first = create_essential(course: @course, name: "La méiose")
    second = create_essential(course: @course, name: "La mitose")
    sign_in_as student

    create_essential_read(student:, essential: second)
    get courses_path
    assert_select "#course_#{@course.slug} a[href='#{course_essential_path(@course.slug, second.slug)}'][data-turbo-prefetch=false]",
                  text: including(tl("course_card.progress.started"))
    assert_select "#course_#{@course.slug} svg.text-success", 0
    assert_select "#course_#{@published.slug} a[href='#{course_path(@published.slug)}']" do
      assert_select "*", text: including(tl("course_card.progress.started")), count: 0
    end

    create_essential_read(student:, essential: first, at: 1.day.ago)
    get courses_path
    assert_select "#course_#{@course.slug} a[href='#{course_path(@course.slug)}']" do
      assert_select ".sr-only", text: tl("course_card.progress.done")
      assert_select "svg.text-success", 1
    end
  end

  # CA-15 (UDR-0085 §3.2) : 24 cartes ; la page suivante reçoit la matière de la dernière carte et ne répète pas son titre.
  test "CA-15: the next page carries after_material and does not repeat the title of the open group" do
    maths = create_material(name: "Mathématiques")
    30.times { |index| create_course(name: format("Algèbre %02d", index), level: @tle, material: maths) }
    sign_in_as create_student_for(@course)
    next_path = courses_path(page: 2, after_material: "mathematiques")

    get courses_path

    assert_select "#courses_total", text: including(tl("index.total", count: 32))
    assert_select "#courses_groups > section", 1
    assert_select "#courses_group_mathematiques h2", text: including(tl("course_group_title.count", count: 30))
    assert_select "#courses_groups li", 24
    assert_select "turbo-frame#courses_page_2[loading=lazy][src='#{next_path}']"

    get next_path, headers: { "Turbo-Frame" => "courses_page_2" }

    assert_select "#courses_groups_page_2 > div:first-child li", 6
    assert_select "#courses_groups_page_2 h2", 2
    assert_select "#courses_group_mathematiques", 0
    assert_equal %w[courses_group_svt courses_group_philosophie], css_select("#courses_groups_page_2 > section").map { it["id"] }
    assert_icons_drawn_once "turbo-frame#courses_page_2"
  end

  # UDR-0054 §3.2: from the filtered catalogue, « Cours » brings back to the same filter; from anywhere else, or from
  # another site, to the bare catalogue.
  test "the back link of a course keeps the filter of the catalogue the student came from, never another site's address" do
    sign_in_as create_student_for(@course)
    back = "nav[aria-label='#{I18n.t('components.back_link.label')}'] a[href=?]"
    filtered = courses_path(material: @svt.slug)

    get course_path(@course.slug), headers: { "Referer" => "http://www.example.com#{filtered}" }
    assert_select back, filtered, text: "Cours"

    get course_path(@course.slug), headers: { "Referer" => "http://www.example.com#{student_home_path}" }
    assert_select back, courses_path

    get course_path(@course.slug), headers: { "Referer" => "https://ailleurs.example#{filtered}" }
    assert_select back, courses_path
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
    maths = create_material(name: "Mathématiques", shortname: "Maths")
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
    # UDR enseignant §3.7 : « 2 fiches de cours · Maths · Progression DPFC 2026-2027 », une seule fois ; plus de menus.
    assert_select "#courses_total", text: tl("index.teacher_total", total: tl("index.total", count: 2), material: "Maths")
    assert_select "form#courses-filters" do
      assert_select "select", 0
      assert_select "input[type=search][name=q]"
    end
    assert_select "#courses_material_chips", 0
    assert_select "#course_#{own.slug}", text: /Tle/, count: 0
    assert_select "#courses_groups, h2[id^=courses_group_]", 0
  end

  # CA-G5 (UDR enseignant §3.7) : l'adresse d'un rond de niveau de l'accueil.
  test "CA-G5: a level bubble opens « Cours de Tle D » under « Accueil », without Niveau nor Série menus, nor « Tle D » on the lines" do
    maths = create_material(name: "Mathématiques", shortname: "Maths")
    d = @course.series
    own = create_course(name: "Probabilités", level: @tle, series: d, material: maths, subtitle: "Leçon 1 · Progression DPFC 2026-2027")
    other_level = create_course(name: "Calcul littéral", level: @seconde, material: maths)
    link_level_series(level: @tle, series: d)
    sign_in_as create_teacher(material: maths, classrooms: [ create_classroom(level: @tle, series: d), create_classroom(level: @seconde) ])

    get courses_path(level: "tle", series: "d", material: "mathematiques")

    assert_response :success
    assert_select "h1", text: "Cours de Tle D"
    assert_select "title", text: including("Cours de Tle D")
    assert_select "nav a[href='#{teacher_home_path}']", text: "Accueil"
    assert_select "form#courses-filters select", 0
    assert_select "form#courses-filters" do
      assert_select "input[type=hidden][name=level][value=tle]"
      assert_select "input[type=hidden][name=series][value=d]"
      assert_select "input[type=hidden][name=material][value=mathematiques]"
    end
    assert_select "#course_#{own.slug}"
    assert_select "#course_#{other_level.slug}", 0
    assert_no_match(/Tle D/, css_select("#courses_list, #main ul").map(&:text).join(" "))

    get courses_path(level: "tle")
    assert_select "h1", text: "Cours de Tle"

    get courses_path(level: "inconnu")
    assert_select "h1", text: "Cours"

    get courses_path
    assert_select "h1", text: "Cours"
    assert_select "nav a[href='#{teacher_home_path}']", text: "Accueil"
  end

  # CA-G5, CA-N1 : les puces d'un bivalent sont ses matières de l'établissement courant, une seule à la fois.
  test "CA-N1: a teacher of two subjects gets chips of those of the current school only, one subject at a time, first active" do
    maths = create_material(name: "Mathématiques", shortname: "Maths")
    pc = create_material(name: "Physique-Chimie", shortname: "PC", category: "science")
    d = @course.series
    limits = create_course(name: "Limites", level: @tle, series: d, material: maths, subtitle: "Leçon 1 · Progression DPFC 2026-2027")
    mechanics = create_course(name: "Mécanique", level: @tle, series: d, material: pc)
    link_level_series(level: @tle, series: d)
    teacher = create_teacher(materials: [ maths, pc ], classrooms: [ create_classroom(level: @tle, series: d) ])
    add_teacher_school(teacher, create_school, materials: [ @svt ])
    sign_in_as teacher

    get courses_path(level: "tle", series: "d")

    assert_equal [ "Maths", "PC" ], css_select("#courses_material_chips a").map(&:text).map(&:strip)
    assert_select "#courses_material_chips a[aria-current=true]", text: "Maths"
    assert_select "#courses_material_chips a[aria-current]", 1
    assert_select "#courses_material_chips a[href='#{courses_path(level: "tle", series: "d", material: pc.slug)}']", text: "PC"
    assert_select "#course_#{limits.slug}"
    [ mechanics, @course ].each { assert_select "#course_#{it.slug}", 0 }
    assert_select "#courses_total", text: including("Maths")
    assert_select "#courses_groups, h2[id^=courses_group_], form#courses-filters select", 0
    # CA-N2 : dès lg, une colonne de 40 rem, une carte par ligne ; sous lg, la page garde ses classes d'avant.
    assert_select "#teacher_courses.lg\\:max-w-160 #courses_list.lg\\:grid-cols-1.sm\\:grid-cols-2"
    assert_select "#courses_list.xl\\:grid-cols-3", 0

    get courses_path(level: "tle", series: "d", material: pc.slug)

    assert_select "#courses_material_chips a[aria-current=true]", text: "PC"
    assert_select "#course_#{mechanics.slug}"
    assert_select "#course_#{limits.slug}", 0
    assert_select "#courses_total", text: including("PC")

    # Une matière qui n'est pas la sienne dans cet établissement (celle d'un autre) : sa première, jamais celle-là.
    get courses_path(level: "tle", series: "d", material: @svt.slug)

    assert_select "#courses_material_chips a[aria-current=true]", text: "Maths"
    assert_select "#course_#{@course.slug}", 0
  end

  # CA-N1 : une carte par fiche de cours, qui porte ses fiches de révision publiées.
  test "CA-N1: each course is a card « LEÇON N · title » that lists its published review sheets as links" do
    maths = create_material(name: "Mathématiques", shortname: "Maths")
    d = @course.series
    limits = create_course(name: "Limites et continuité", level: @tle, series: d, material: maths,
                           subtitle: "Leçon 1 · Progression DPFC 2026-2027")
    alone = create_course(name: "Fonctions logarithmes", level: @tle, series: d, material: maths, subtitle: "Leçon 3 · Progression DPFC 2026-2027")
    first = create_essential(course: limits, name: "Limites en l'infini", position: 1)
    second = create_essential(course: limits, name: "Continuité", position: 2)
    create_essential(course: limits, name: "Brouillon", position: 3, status: "draft")
    link_level_series(level: @tle, series: d)
    sign_in_as create_teacher(material: maths, classrooms: [ create_classroom(level: @tle, series: d) ])

    get courses_path(level: "tle", series: "d")

    assert_select "#course_#{limits.slug}" do
      assert_select "a[href='#{course_path(limits.slug)}']", text: including("Leçon 1")
      assert_select "a[href='#{course_path(limits.slug)}']", text: including("Limites et continuité")
      assert_select "a[href='#{course_path(limits.slug)}']", text: /Progression DPFC/, count: 0
      assert_select "*", text: including(tl("show.essentials_title"))
      assert_equal [ course_essential_path(limits.slug, first.slug), course_essential_path(limits.slug, second.slug) ],
                   css_select("#course_#{limits.slug} ul a").map { it["href"] }
      assert_select "ul a", text: "Limites en l'infini"
      assert_select "*", text: including("Brouillon"), count: 0
    end
    # Sans fiche de révision : la carte n'a que son en-tête.
    assert_select "#course_#{alone.slug}" do
      assert_select "a[href='#{course_path(alone.slug)}']", text: including("Fonctions logarithmes")
      assert_select "ul", 0
      assert_select "*", text: including(tl("show.essentials_title")), count: 0
    end
  end

  test "CA-N1: searching keeps the active subject and the level, and « Tout voir » leaves the search only" do
    maths = create_material(name: "Mathématiques", shortname: "Maths")
    pc = create_material(name: "Physique-Chimie", shortname: "PC")
    d = @course.series
    create_course(name: "Limites", level: @tle, series: d, material: maths)
    create_course(name: "Dérivées", level: @tle, series: d, material: maths)
    link_level_series(level: @tle, series: d)
    sign_in_as create_teacher(materials: [ maths, pc ], classrooms: [ create_classroom(level: @tle, series: d) ])

    get courses_path(level: "tle", series: "d", material: pc.slug)
    assert_select "#courses_reset", 0

    get courses_path(level: "tle", series: "d", material: maths.slug, q: "limi"), headers: { "Turbo-Frame" => "courses" }
    assert_select "#courses_list > li", 1
    assert_select "#courses_reset[href='#{courses_path(level: "tle", series: "d", material: maths.slug)}']", text: tl("index.reset")

    get courses_path(level: "tle", series: "d", q: "zzz")
    assert_select "#courses_empty", text: including(tl("index.no_match_title"))
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
  test "CA-6: the search and filters show on a phone too; a filtered list offers « Tout voir » at every width" do
    sign_in_as create_team_member

    get courses_path

    assert_select "form#courses-filters.grid"
    assert_select "form#courses-filters.hidden", 0
    assert_select "#courses_reset", 0

    get courses_path(material: @svt.slug)

    assert_select "turbo-frame#courses #courses_reset.min-h-tap[href='#{courses_path}']", text: tl("index.reset")
    assert_select "#courses_reset.sm\\:hidden", 0
  end

  # CA-2, CA-4 (UDR-0085 §3.1) : chez l'élève, « Tout voir » n'apparaît que pendant une recherche, et l'efface.
  test "CA-2, CA-4: the student's « Tout voir » shows only while searching; the found courses stay under their subject" do
    sign_in_as create_student_for(@course)

    get courses_path
    assert_select "form#courses-filters.flex"
    assert_select "#courses_reset", 0

    get courses_path(q: "geneti"), headers: { "Turbo-Frame" => "courses" }
    assert_select "#courses_reset.min-h-tap[href='#{courses_path}']", text: tl("index.reset")
    assert_select "#courses_group_svt li#course_#{@course.slug}"
    assert_select "#courses_group_philosophie", 0
  end

  test "the colour and icon of a subject come from its category, never from its name (CA-26)" do
    create_course(name: "Analyse", level: @tle, material: create_material(name: "Mathématiques", category: "literature"))
    sign_in_as create_team_member

    get courses_path

    literature = ComponentsHelper::BADGE_TONES.fetch(:gold)[:chip]
    science = ComponentsHelper::BADGE_TONES.fetch(:brand)[:chip]
    assert_select "#courses_list li", text: /Analyse/ do
      assert_select "span[class*='#{literature}']", text: "Mathématiques"
    end
    assert_select "#course_#{@course.slug} span[class*='#{science}']", text: "SVT"
  end

  # ── Page d'un cours ────────────────────────────────────────────────────────

  test "a student reads a published course: back link, badges, then « Fiche de révision » and « Prépare interros »" do
    meiose = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions")
    create_exercise(essential: meiose)
    create_essential(course: @course, name: "Fiche en brouillon", status: "draft")
    sign_in_as create_student_for(@course)

    get course_path(@course.slug)

    assert_response :success
    assert_select "title", text: "Génétique et évolution · Élève · Lnclass"
    # FU-14 : le seul retour est « Cours », vers le catalogue ; le fil complet a disparu.
    assert_select "main nav", 1
    assert_select "nav[aria-label=?] a[href='#{courses_path}']", I18n.t("components.back_link.label"), text: "Cours"
    assert_no_match(/href="#{Regexp.escape(courses_path)}\?material=/, response.body)
    assert_select "main [aria-current=page]", 0
    assert_select "#course_header h1", text: "Génétique et évolution"
    assert_select "#course_header", text: including("Du gène à l'espèce")
    assert_select "#course_header", text: including("Tle D")
    assert_select "#course_header", text: including("SVT")
    # UDR page de la leçon §3.1 : deux sections, plus de liste de notions ; le Lot 0 les montre à l'état vide.
    assert_select "#course_essentials", 0
    assert_select "section#fiche-de-revision h2", text: tl("show.revision_title")
    assert_select "section#fiche-de-revision", text: including(tl("show.revision_empty"))
    assert_select "section#prepare-interros[data-turbo-prefetch=false] h2", text: tl("show.prepare_title")
    assert_select "section#prepare-interros", text: including(tl("show.prepare_intro"))
    assert_select "section#prepare-interros", text: including(tl("show.exercises_empty"))
    assert_no_match(/Fiche en brouillon/, response.body)
    assert_select "#content_status_course_#{@course.slug}", 0
    assert_select "#course-actions-menu", 0
    assert_select "a[href='#{assignments_href(@course.slug)}']", 0
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
    assert_match including("Actions sur la fiche de cours « Brouillon de cours »"), response.body
    assert_select "#course-actions-menu" do
      assert_select "a[role=menuitem][data-turbo-method=patch][href='#{publish_teams_course_path(@draft.slug)}']"
      assert_select "a[role=menuitem][data-turbo-method=patch][href='#{publish_all_teams_course_path(@draft.slug)}']",
                    text: I18n.t("catalog.content_status.actions.publish_all")
      assert_select modal_link(edit_teams_course_path(@draft.slug)), text: tl("role_actions.edit")
      assert_select modal_link(new_teams_course_essential_path(@draft.slug)), text: tl("role_actions.new_essential")
      assert_select modal_link(new_teams_import_path(kind: "essentials", course: @draft.slug)),
                    text: tl("role_actions.import_essentials")
    end
    assert_select "#course_essentials", 0
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

  test "a course without content shows both sections empty, without the former sheet button" do
    bare = create_course(name: "Cours vide", content: nil)
    sign_in_as create_student_for(bare)

    get course_path(bare.slug)

    assert_select "#fiche-de-revision", text: including(tl("show.revision_empty"))
    assert_select "#prepare-interros", text: including(tl("show.exercises_empty"))
    assert_select "#course_content", 0
    assert_select "#course_sheet_link", 0
  end

  # Le texte de la leçon redevient visible dans la fiche de révision avec le Lot A ; sa sanitisation (CA-04) y sera rejouée.
  test "the content is sanitised on render: no script tag, no event attribute, no javascript link (CA-04)" do
    skip "Lot A : le texte de la leçon est rendu par la fiche de révision"
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

  # ── Cours par leçons, sur ordinateur (Lot O5, CA-E14, CA-E15) ──────────────

  def lessons_student = @lessons_student ||= create_student_for(@course)
  def current_pill = css_select("#lesson_materials a[aria-current=page]").map { it["id"] }
  def lesson_ids = css_select("#student_lessons li[id^=lesson_]").map { it["id"] }.grep_v(/\Alesson_essential_/)

  test "CA-E15: without ?material=, a student gets the first subject of the grid, the 6 pills, and the phone view is kept" do
    sign_in_as lessons_student

    get courses_path

    assert_response :success
    assert_select "nav#lesson_materials[aria-label=?] a", tl("index.lessons.materials_label"), 2
    assert_equal [ "lesson_material_#{@svt.slug}" ], current_pill
    assert_equal [ "lesson_#{@course.slug}" ], lesson_ids
    assert_select "#lessons_total", text: tl("index.student_total", total: tl("index.total", count: 1))
    # Le téléphone garde le Cours de CA-E6 : un groupe par matière, les cartes de l'élève en lignes.
    assert_select "#courses_groups > section", 2
    assert_select "#courses_groups li#course_#{@course.slug}"
  end

  test "CA-E15: ?material= opens that subject, which Cours then remembers in the session" do
    sign_in_as lessons_student

    get courses_path(material: @philo.slug)

    assert_equal [ "lesson_material_#{@philo.slug}" ], current_pill
    assert_equal [ "lesson_#{@published.slug}" ], lesson_ids

    get courses_path

    assert_equal [ "lesson_material_#{@philo.slug}" ], current_pill
    assert_equal [ "lesson_#{@published.slug}" ], lesson_ids
  end

  test "CA-E15: an unknown subject, or one of another class, falls back to the first subject, and is never remembered" do
    create_course(name: "English", level: @seconde, material: create_material(name: "Anglais"))
    sign_in_as lessons_student
    get courses_path(material: @philo.slug)

    [ "nope", "anglais", "" ].each do |slug|
      get courses_path(material: slug)

      assert_response :success
      assert_equal [ "lesson_material_#{@philo.slug}" ], current_pill, "« #{slug} » : la dernière matière valide reste"
    end
  end

  test "CA-E15: an unknown subject with nothing remembered opens the first subject of the grid" do
    create_course(name: "English", level: @seconde, material: create_material(name: "Anglais"))
    sign_in_as lessons_student

    get courses_path(material: "anglais")

    assert_equal [ "lesson_material_#{@svt.slug}" ], current_pill
    assert_select "#lesson_materials a[href*=anglais]", 0
  end

  test "CA-E15: a remembered subject the student's class no longer has falls back to the first subject" do
    anglais = create_material(name: "Anglais")
    english = create_course(name: "English", level: @tle, material: anglais, series: @course.series)
    student = create_student_for(@course)
    sign_in_as student
    get courses_path(material: anglais.slug)
    assert_equal [ "lesson_material_#{anglais.slug}" ], current_pill

    english.update!(status: "draft", published_at: nil, archived_at: nil)
    get courses_path

    assert_equal [ "lesson_material_#{@svt.slug}" ], current_pill
  end

  test "CA-E14: a lesson card shows its sheets, 3 then « Voir les N fiches », and « À revoir » for this student only" do
    sheets = Array.new(5) { |index| create_essential(course: @course, name: "Fiche #{index + 1}") }
    create_gap(student: lessons_student, essential: sheets.second)
    create_gap(student: create_student_for(@course), essential: sheets.first)
    sign_in_as lessons_student

    get courses_path(material: @svt.slug)

    assert_select "li#lesson_#{@course.slug}" do
      assert_select "li[id^=lesson_essential_]", 5
      assert_select "li[id^=lesson_essential_][hidden]", 2
      assert_select "li#lesson_essential_#{sheets.first.slug} a[href=?]", course_essential_path(@course.slug, sheets.first.slug)
      assert_select "li#lesson_essential_#{sheets.second.slug}", text: including(tl("essential_row.review"))
      assert_select "li#lesson_essential_#{sheets.first.slug}", text: including(tl("essential_row.review")), count: 0
      assert_select "button", text: tl("course_card.more_essentials", count: 5)
    end
  end

  test "CA-E14: a lesson with 3 sheets or fewer has no « Voir les N fiches »" do
    3.times { create_essential(course: @course) }
    sign_in_as lessons_student

    get courses_path(material: @svt.slug)

    assert_select "li#lesson_#{@course.slug} li[id^=lesson_essential_]:not([hidden])", 3
    assert_select "li#lesson_#{@course.slug} button", 0
  end

  test "CA-E14: the lessons read a search on their name, and the subject's pills stay" do
    cell = create_course(name: "La cellule", level: @tle, material: @svt, series: @course.series)
    sign_in_as lessons_student

    get courses_path(material: @svt.slug, q: "cellule")

    assert_equal [ "lesson_#{cell.slug}" ], lesson_ids
    assert_select "#lessons_total", text: including(tl("index.total", count: 1))
    assert_select "nav#lesson_materials a", 2
  end

  test "CA-E14: a student without a class has no pills nor lessons, only the empty state" do
    sign_in_as create_student

    get courses_path

    assert_response :success
    assert_select "nav#lesson_materials", 0
    assert_select "#lessons_empty", text: including(tl("index.no_class_title"))
  end

  test "CA-E14: a student without a class who searches still gets the empty state, not an error" do
    sign_in_as create_student

    get courses_path(q: "x")

    assert_response :success
    assert_select "nav#lesson_materials", 0
    assert_select "#lessons_empty", text: including(tl("index.no_class_title"))
  end

  # CA-E14 : « dans l'ordre du programme » : Leçon 1, 2, 10 (non 10 avant 2, ordre des noms) ; le téléphone garde l'ordre des noms.
  test "CA-E14: the lessons of a subject follow the programme order, the phone view keeps the name order" do
    suites = create_course(name: "Suites", subtitle: "Leçon 10 · Progression DPFC 2026-2027", level: @tle, series: @course.series, material: @svt)
    derivees = create_course(name: "Dérivées", subtitle: "Leçon 2 · Progression DPFC 2026-2027", level: @tle, series: @course.series, material: @svt)
    limites = create_course(name: "Limites", subtitle: "Leçon 1 · Progression DPFC 2026-2027", level: @tle, series: @course.series, material: @svt)
    sign_in_as lessons_student

    get courses_path(material: @svt.slug)

    assert_equal [ limites, derivees, suites, @course ].map { "lesson_#{it.slug}" }, lesson_ids
    assert_equal [ derivees, @course, limites, suites ].map { "course_#{it.slug}" }, css_select("#courses_groups li[id^=course_]").map { it["id"] }
  end

  # La garde current_actor.teacher? de teacher_scope : l'adresse du Cours de l'enseignant ne lui donne pas son en-tête.
  test "CA-E14: a student who opens the teacher's Cours address gets his own Cours, with no teacher header nor subject chips" do
    sign_in_as lessons_student

    get courses_path(level: @tle.slug, series: @course.series.slug)

    assert_response :success
    assert_no_match including(tl("index.teacher_title", level: "Tle D")), response.body
    assert_select "#courses_material_chips", 0
  end

  test "CA-E14: the teacher and the team keep their Cours, with no pills nor lessons block" do
    [ create_teacher(material: @svt, classrooms: [ create_classroom(level: @tle, series: @course.series) ]), create_team_member ].each do |user|
      sign_in_as user

      get courses_path(material: @svt.slug)

      assert_response :success
      assert_select "nav#lesson_materials", 0
      assert_select "#student_lessons", 0
      assert_select "#student_courses", 0
    end
  end
end
