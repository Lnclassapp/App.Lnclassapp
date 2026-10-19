require "test_helper"

module Catalog
  # ADR-0099, UDR-0114 : la page publique d'une matière, ses pastilles de niveau, ses filtres ?niveau= et ?serie=, ses pages
  # de 24 cartes ; jamais un brouillon ni un archivé ; une adresse inconnue répond 404.
  class PublicMaterialPagesTest < ActionDispatch::IntegrationTest
    setup do
      @referential = seed_referential
      @levels = @referential[:levels]
      @series = @referential[:series]
      @pc = @referential[:materials].fetch("physique-chimie")
      @maths = @referential[:materials].fetch("mathematiques")
    end

    def course(level, material = @pc, **attributes) = create_course(level: @levels.fetch(level), material:, **attributes)
    def texts(selector) = css_select(selector).map { it.text.squish }

    test "CC-09: the material page groups its courses by level, in the order of the levels, with the level pills" do
      course("tle", name: "Mécanique")
      course("3eme", name: "Électricité")
      course("4eme", name: "La matière")
      course("4eme", name: "Les mélanges")

      get public_material_path("physique-chimie")

      assert_response :success
      assert_select "h1", "Physique-Chimie"
      assert_select "title", "Fiches de cours de Physique-Chimie · Lnclass"
      assert_select "main p.text-mute", "4 fiches de cours publiées."
      assert_equal %w[level_group_4eme level_group_3eme level_group_tle], css_select("#material_groups > section").map { it["id"] }
      assert_select "#level_group_4eme h2", text: /4ème\s+2 fiches de cours/
      assert_equal [ "Tous les niveaux", "4ème · 2", "3ème · 1", "Tle · 1" ], texts("#material_levels a")
      assert_select "#material_levels a[aria-current=page]", "Tous les niveaux"
      assert_select "#material_levels a[aria-label='4ème, 2 fiches de cours'][href=?]", "/matieres/physique-chimie?niveau=4eme"
      assert_select "head link[rel=canonical][href='https://lnclass.com/matieres/physique-chimie']"
      assert_select "head meta[name=robots]", 0
    end

    test "CC-10: ?niveau= keeps the courses of that level, titles the page and activates its pill" do
      course("tle", name: "Mécanique")
      course("3eme", name: "Électricité")

      get public_material_path("physique-chimie", niveau: "3eme")

      assert_response :success
      assert_select "h1", "Physique-Chimie en 3ème"
      assert_select "title", "Physique-Chimie en 3ème · Lnclass"
      assert_select "#material_levels a[aria-current=page]", "3ème · 1"
      assert_select "#material_groups section", 0
      assert_select "#material_groups h3", "Électricité"
      assert_no_match "Mécanique", response.body
      assert_select "head link[rel=canonical][href=?]", "https://lnclass.com/matieres/physique-chimie?niveau=3eme"
      assert_select "main nav a[href='/niveaux/3eme']", text: "3ème"
    end

    test "CC-17: ?niveau=&serie= keeps the series and the common courses, and titles « en Tle D »" do
      course("tle", @maths, name: "Suites", series: @series.fetch("d"))
      course("tle", @maths, name: "Matrices", series: @series.fetch("c"))
      course("tle", @maths, name: "Logique")

      get public_material_path("mathematiques", niveau: "tle", serie: "d")

      assert_response :success
      assert_select "h1", "Mathématiques en Tle D"
      assert_equal [ "Logique", "Suites" ], texts("#material_groups h3")
      assert_select "main p.text-mute", "2 fiches de cours publiées."
      assert_select "#material_levels a[aria-current=page]", "Tle · 3"
      assert_select "#material_levels a[href='/matieres/mathematiques']", "Tous les niveaux"
      assert_select "main nav a[href='/niveaux/tle/d']", text: "Tle D"
      assert_select "head link[rel=canonical][href=?]", "https://lnclass.com/matieres/mathematiques?niveau=tle&serie=d"
    end

    test "CC-06: neither a draft nor an archived course, nor their count, on the material page" do
      course("tle", @maths, name: "Suites")
      course("tle", @maths, name: "Intégrales", status: "draft")
      course("tle", @maths, name: "Limites", status: "archived")
      course("1ere", @maths, name: "Dérivées", status: "draft")

      get public_material_path("mathematiques")

      assert_select "#material_groups h3", "Suites"
      assert_equal [ "Tous les niveaux", "Tle · 1" ], texts("#material_levels a")
      assert_no_match(/Intégrales|Limites|Dérivées|1ère/, response.body)

      get public_material_path("mathematiques", niveau: "1ere")
      assert_response :not_found
    end

    test "CC-12: an unknown material, level or series, a series without level or not attached is not found" do
      course("tle", @maths)

      [ public_material_path("inconnue"), public_material_path("mathematiques", niveau: "inconnu"),
        public_material_path("mathematiques", serie: "d"), public_material_path("mathematiques", niveau: "tle", serie: "inconnue"),
        "/matieres/mathematiques?niveau=tle&serie[]=d",
        public_material_path("mathematiques", niveau: "tle", serie: "a"), "/matieres/mathematiques?niveau[]=tle" ].each do |path|
        get path

        assert_response :not_found, path
      end
    end

    test "CC-07: the material page links to no content and its cards hold no link nor button" do
      published = course("tle", @maths, name: "Suites", subtitle: "Arithmétiques")
      create_essential(course: published, name: "Fiche des suites")

      get public_material_path("mathematiques")

      assert_select "article", 1
      assert_select "article a, article button", 0
      assert_select "a[href^='/courses/'], a[href*='/essentials/'], a[href^='/exercises']", 0
    end

    test "a foreign Turbo-Frame id gets the full page, not the cards frame" do
      course("tle", @maths)

      get public_material_path("mathematiques"), headers: { "Turbo-Frame" => "autre" }

      assert_response :success
      assert_match(/<html/, response.body)
    end

    test "CC-13: a material without published course says its courses are coming and is not indexed" do
      course("tle", @maths, status: "draft")

      get public_material_path("mathematiques")

      assert_response :success
      assert_select "#material_empty", text: /Les fiches de cours de cette matière arrivent bientôt\./
      assert_select "#material_empty a[href='#{public_levels_path}']", "Voir les niveaux"
      assert_select "#material_levels", 0
      assert_select "head meta[name=robots][content=noindex]"
    end

    test "CC-11: 24 cards a page, the next one in a lazy frame and, without JavaScript, the full page 2" do
      12.times { |index| course("3eme", @maths, name: format("Cours 3e %02d", index)) }
      18.times { |index| course("tle", @maths, name: format("Cours Tle %02d", index)) }

      get public_material_path("mathematiques")

      assert_select "#material_groups article", 24
      next_path = "/matieres/mathematiques?after_level=tle&page=2"
      assert_select "turbo-frame#material_courses_page_2[loading=lazy][target=_top][src=?]", next_path
      assert_select "turbo-frame#material_courses_page_2 a[href=?]", next_path, text: "Afficher plus de fiches de cours"

      get next_path, headers: { "Turbo-Frame" => "material_courses_page_2" }
      assert_response :success
      assert_select "turbo-frame#material_courses_page_2 article", 6
      assert_select "turbo-frame#material_courses_page_2 section", 0
      assert_no_match(/<html/, response.body)

      get public_material_path("mathematiques", page: 2)
      assert_select "#material_groups article", 6
      assert_select "#material_groups section#level_group_tle h2", text: /Tle\s+18 fiches de cours/
      assert_select "head link[rel=canonical][href='https://lnclass.com/matieres/mathematiques']"
      assert_select "turbo-frame[id^=material_courses_page]", 0
    end

    test "the next page of a filtered list keeps its filters, and a page out of range is the nearest one" do
      26.times { |index| course("tle", @maths, name: format("Cours %02d", index), series: @series.fetch("d")) }

      get public_material_path("mathematiques", niveau: "tle", serie: "d")
      assert_select "turbo-frame#material_courses_page_2[src=?]", "/matieres/mathematiques?after_level=tle&niveau=tle&page=2&serie=d"

      get public_material_path("mathematiques", niveau: "tle", serie: "d", page: 9)
      assert_select "#material_groups article", 2
    end

    test "CC-20: no shared cache, and a visitor, a student and a teacher read the same page without redirection" do
      published = course("tle", @maths, name: "Suites", series: @series.fetch("d"))

      get public_material_path("mathematiques")
      assert_no_match(/public/, response.headers["Cache-Control"])
      assert_match(/private/, response.headers["Cache-Control"])
      assert_select "#material_cta_top a[href='#{new_student_registration_path}']", "Créer mon compte élève"

      sign_in_as create_student_for(published)
      get public_material_path("mathematiques")
      assert_response :success
      assert_select "#material_cta_bottom a[href='#{courses_path}']", "Voir mes fiches de cours"

      published.update!(status: "archived")
      get public_material_path("mathematiques")
      assert_no_match "Suites", response.body
    end
  end
end
