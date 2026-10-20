require "test_helper"

module Catalog
  # ADR-0099, UDR-0113 : /niveaux et l'Espace Niveau se lisent sans compte et connecté, sans redirection ; ils ne montrent
  # que le nom et la description des cours publiés, jamais un brouillon, un archivé ni un lien vers un contenu.
  class PublicLevelPagesTest < ActionDispatch::IntegrationTest
    setup do
      @referential = seed_referential
      @levels = @referential[:levels]
      @materials = @referential[:materials]
      @series = @referential[:series]
    end

    def course(level, material, **attributes) = create_course(level: @levels.fetch(level), material: @materials.fetch(material), **attributes)
    def texts(selector) = css_select(selector).map { it.text.squish }

    test "CC-01: /niveaux lists the levels with a published course, by cycle, with their number of courses" do
      course("6eme", "mathematiques")
      course("3eme", "svt")
      course("3eme", "francais")
      course("tle", "philosophie")
      course("5eme", "mathematiques", status: "draft")

      get public_levels_path

      assert_response :success
      assert_select "h1", "Les fiches de cours par niveau"
      assert_equal [ "6ème 1 fiche de cours", "3ème 2 fiches de cours" ], texts("#cycle_first li a")
      assert_equal "Premier cycle", css_select("#cycle_first h2").first.text.squish
      assert_select "#cycle_second h2", "Second cycle"
      assert_select "#cycle_second li a[href='/niveaux/tle']", text: /Tle\s+1 fiche de cours\s+Séries A1, A2, C, D/
      assert_select "a[href='/niveaux/5eme']", 0
      assert_select "head meta[name=robots]", 0
      assert_select "head link[rel=canonical][href='https://lnclass.com/niveaux']"
      assert_select "title", "Les fiches de cours par niveau · Lnclass"
    end

    test "CC-02: without a published course, /niveaux says the courses are coming and is not indexed" do
      course("tle", "mathematiques", status: "draft")

      get public_levels_path

      assert_response :success
      assert_select "#levels_empty", text: /Les fiches de cours arrivent bientôt\./
      assert_select "head meta[name=robots][content=noindex]"
      assert_select "#cycle_first, #cycle_second", 0
    end

    test "CC-03: the level space groups its courses by material, in the program order, with each count" do
      course("tle", "svt", name: "Génétique")
      course("tle", "philosophie", name: "La conscience")
      2.times { |index| course("tle", "mathematiques", name: "Suites #{index}") }

      get public_level_path("tle")

      assert_response :success
      assert_select "h1", "Fiches de cours de Tle"
      assert_select "title", "Fiches de cours de Tle · Lnclass"
      assert_select "main p.text-mute", text: "4 fiches de cours publiées, en 3 matières."
      assert_equal %w[group_mathematiques group_svt group_philosophie], css_select("#level_groups > section").map { it["id"] }
      assert_select "#group_mathematiques h2 a[href=?]", "/matieres/mathematiques?niveau=tle", text: /Mathématiques\s+2 fiches de cours/
      assert_select "head meta[name=description][content='Les fiches de cours de Tle sur Lnclass : Mathématiques, SVT, Philosophie.']"
      assert_select "head link[rel=canonical][href='https://lnclass.com/niveaux/tle']"
    end

    test "CC-04: six cards per material, then « Voir les 9 fiches de cours » to the material page filtered on the level" do
      9.times { |index| course("tle", "mathematiques", name: "Cours #{index}") }
      course("tle", "svt")
      course("tle", "physique-chimie")
      course("tle", "francais")

      get public_level_path("tle")

      assert_select "#group_mathematiques li", 6
      assert_select "#group_mathematiques_more[href=?]", "/matieres/mathematiques?niveau=tle", text: "Voir les 9 fiches de cours"
      assert_select "#group_svt_more", 0
      assert_select "head meta[name=description][content='Les fiches de cours de Tle sur Lnclass : Mathématiques, Physique-Chimie, SVT, ….']"
    end

    test "CC-05: a series pill only for a series with a course of its own or a common one" do
      course("tle", "mathematiques", series: @series.fetch("d"))
      course("tle", "physique-chimie", series: @series.fetch("c"), status: "draft")

      get public_level_path("tle")

      assert_equal [ "Tle D" ], texts("#level_series a")
      assert_select "#level_series a[href='/niveaux/tle/d']"
    end

    test "CC-06: neither a draft nor an archived course, not even its title, on /niveaux nor on the level space" do
      course("tle", "mathematiques", name: "Suites", subtitle: "Arithmétiques et géométriques")
      course("tle", "mathematiques", name: "Intégrales", subtitle: "Brouillon secret", status: "draft")
      course("tle", "mathematiques", name: "Limites", subtitle: "Cours retiré", status: "archived")
      course("1ere", "mathematiques", name: "Dérivées", status: "draft")

      get public_levels_path
      assert_select "#cycle_second li", 1
      assert_select "#level_tle", text: /1 fiche de cours/
      assert_no_match(/1ère|Intégrales|Limites|Brouillon secret/, response.body)

      get public_level_path("tle")
      assert_select "#group_mathematiques li", 1
      assert_select "#group_mathematiques h3", "Suites"
      assert_select "#group_mathematiques p", "Arithmétiques et géométriques"
      assert_match "1 fiche de cours publiée, en 1 matière.", response.body
      assert_no_match(/Intégrales|Limites|Brouillon secret|Cours retiré/, response.body)
    end

    test "CC-07: a card shows the name and the description of the course, and the page links to no content" do
      published = course("tle", "mathematiques", name: "Suites", subtitle: "Arithmétiques et géométriques")
      create_essential(course: published, name: "Fiche des suites")
      course("tle", "svt", name: "Génétique", subtitle: nil)

      get public_level_path("tle")

      assert_select "#group_svt article p", 0
      assert_select "article a, article button", 0
      assert_select "a[href^='/courses/'], a[href*='/essentials/'], a[href^='/exercises'], a[href^='/sessions']", 0
      assert_no_match(/Fiche des suites|published|draft/, response.body)
    end

    test "CC-08: a visitor is offered the student account and the sign-in, without being redirected" do
      course("tle", "mathematiques")

      [ public_levels_path, public_level_path("tle") ].each do |path|
        get path

        assert_response :success
        assert_select "a[href='#{new_student_registration_path}']", text: "Créer mon compte élève", minimum: 1
        assert_select "a[href='#{new_session_path}']", text: "J'ai déjà un compte", minimum: 1
        assert_select "header a[href='#{new_session_path}']", text: "Se connecter"
      end
      assert_select "#level_cta_top, #level_cta_bottom", 2
    end

    test "CC-08: a signed-in student is offered « Voir mes fiches de cours », a teacher « Ouvrir le catalogue », both on the same page" do
      published = course("tle", "mathematiques", series: @series.fetch("d"))

      sign_in_as create_student_for(published)
      get public_level_path("tle")
      assert_response :success
      assert_select "#level_cta_top a[href='#{courses_path}']", "Voir mes fiches de cours"
      assert_select "a[href='#{new_student_registration_path}']", 0
      assert_select "header a[href='#{root_path}']", text: "Mon espace"
      assert_select "title", "Fiches de cours de Tle · Élève · Lnclass"

      sign_in_as create_teacher
      get public_levels_path
      assert_response :success
      assert_select "#levels_cta a[href='#{courses_path}']", "Ouvrir le catalogue"
    end

    test "CC-08: a visitor is offered the student account and the sign-in on the four pages" do
      course("tle", "mathematiques", series: @series.fetch("d"))

      [ public_levels_path, public_level_path("tle"), public_material_path("mathematiques"), public_level_series_path("tle", "d") ].each do |path|
        get path

        assert_response :success, path
        assert_select "a[href='#{new_student_registration_path}']", text: "Créer mon compte élève", minimum: 1
        assert_select "a[href='#{new_session_path}']", text: "J'ai déjà un compte", minimum: 1
      end
    end

    test "CC-08: a signed-in student reads « Voir mes fiches de cours » on the series page" do
      published = course("tle", "mathematiques", series: @series.fetch("d"))
      sign_in_as create_student_for(published)

      get public_level_series_path("tle", "d")

      assert_response :success
      assert_select "a[href='#{courses_path}']", text: "Voir mes fiches de cours", minimum: 1
    end

    test "CC-08: a teacher waiting for a school reads the page, then is sent to the pending account from the catalogue" do
      course("tle", "mathematiques")
      sign_in_as create_teacher(school: nil)

      get public_level_path("tle")
      assert_response :success

      get courses_path
      assert_redirected_to pending_account_path
    end

    test "CC-08: a team member and a school direction are offered the catalogue and never read a draft" do
      course("tle", "mathematiques", name: "Suites")
      course("tle", "mathematiques", name: "Intégrales", status: "draft")

      [ create_team_member(team_role: "content"), create_school_admin ].each do |member|
        sign_in_as member

        get public_level_path("tle")

        assert_response :success, member.role
        assert_select "#level_cta_top a[href='#{courses_path}']", "Ouvrir le catalogue"
        assert_no_match "Intégrales", response.body
        delete session_path
      end
    end

    test "CC-23: with about 200 published courses, the level space stays under 150 Ko of HTML" do
      materials = @materials.values
      200.times { |index| course("tle", materials[index % materials.size].slug, name: format("Cours %03d", index), subtitle: "Description du cours #{index}") }

      get public_level_path("tle")

      assert_response :success
      assert_operator response.body.bytesize, :<, 150.kilobytes
    end

    test "CC-19: a Tle D student reads the titles of 6e, but neither the 6e catalogue nor a 6e course" do
      own = course("tle", "mathematiques", name: "Suites", series: @series.fetch("d"))
      other = course("6eme", "mathematiques", name: "Les nombres entiers")
      sign_in_as create_student_for(own)

      get public_level_path("6eme")
      assert_response :success
      assert_select "#group_mathematiques h3", "Les nombres entiers"

      get courses_path
      assert_match "Suites", response.body
      assert_no_match "Les nombres entiers", response.body

      get course_path(other.slug)
      assert_response :not_found
    end

    test "CC-20: no shared cache, and an unpublished course is gone at the next visit" do
      published = course("tle", "mathematiques", name: "Suites")

      [ public_levels_path, public_level_path("tle") ].each do |path|
        get path
        assert_no_match(/public/, response.headers["Cache-Control"])
        assert_match(/private/, response.headers["Cache-Control"])
      end
      assert_match "Suites", response.body

      published.update!(status: "draft")
      get public_level_path("tle")

      assert_no_match "Suites", response.body
      assert_select "#level_empty", text: /Les fiches de cours de ce niveau arrivent bientôt\./
      assert_select "#level_empty a[href='#{public_levels_path}']", "Voir les autres niveaux"
      assert_select "head meta[name=robots][content=noindex]"
    end

    test "CC-12: an unknown level, or a forged one, is not found" do
      get public_level_path("inconnu")
      assert_response :not_found

      get "/niveaux/tle%5B%5D"
      assert_response :not_found
    end

    test "the shared head: description, canonical on the canonical host and the sharing tags, in the blog's order" do
      course("tle", "mathematiques")

      get public_level_path("tle"), headers: { "HOST" => "example.org" }

      assert_equal %w[description canonical og:site_name og:locale og:type og:title og:description og:url og:image
                      og:image:width og:image:height og:image:alt],
                   css_select("head meta[name=description], head link[rel=canonical], head meta[property]")
                     .map { it["name"] || it["rel"] || it["property"] }
      assert_select "head meta[property='og:url'][content='https://lnclass.com/niveaux/tle']"
      assert_select "head meta[property='og:type'][content=website]"
      assert_select "footer a[href='#{public_levels_path}']", "Les fiches de cours par niveau"
    end
  end
end
