require "test_helper"

module Catalog
  # ADR-0099, UDR-0115 : la page publique d'un niveau et de sa série montre les cours de la série et les cours communs du
  # niveau, jamais un brouillon ni un archivé ; une série non rattachée au niveau répond 404.
  class PublicSeriesPagesTest < ActionDispatch::IntegrationTest
    setup do
      @referential = seed_referential
      @tle = @referential[:levels].fetch("tle")
      @series = @referential[:series]
      @materials = @referential[:materials]
    end

    def course(material, **attributes) = create_course(level: @tle, material: @materials.fetch(material), **attributes)
    def texts(selector) = css_select(selector).map { it.text.squish }

    test "CC-14: the series page shows the courses of the series and the common ones, never another series" do
      course("mathematiques", name: "Suites", series: @series.fetch("d"))
      course("physique-chimie", name: "Mécanique", series: @series.fetch("c"))
      course("philosophie", name: "Philosophie morale")

      get public_level_series_path("tle", "d")

      assert_response :success
      assert_select "h1", "Fiches de cours de Tle D"
      assert_select "title", "Fiches de cours de Tle D · Lnclass"
      assert_equal [ "Suites", "Philosophie morale" ], texts("#series_groups h3")
      assert_no_match "Mécanique", response.body
      assert_select "main p.text-mute", "2 fiches de cours publiées, en 2 matières, dont les fiches de cours communes à toutes les séries de Tle."
      assert_select "main nav a[href='/niveaux/tle']", text: "Tle"
      assert_select "head link[rel=canonical][href='https://lnclass.com/niveaux/tle/d']"
      assert_select "head meta[name=description][content='Les fiches de cours de Tle D sur Lnclass : Mathématiques, Philosophie.']"
      assert_select "head meta[name=robots]", 0
    end

    test "without a common course, the summary does not speak of them" do
      course("mathematiques", series: @series.fetch("d"))

      get public_level_series_path("tle", "d")

      assert_select "main p.text-mute", "1 fiche de cours publiée, en 1 matière."
    end

    test "CC-15: a series not attached to the level, an unknown level or series is not found" do
      create_course(level: @referential[:levels].fetch("6eme"), material: @materials.fetch("mathematiques"))

      [ public_level_series_path("6eme", "d"), public_level_series_path("tle", "inconnue"),
        public_level_series_path("inconnu", "d"), public_level_series_path("tle", "a") ].each do |path|
        get path

        assert_response :not_found, path
      end
    end

    test "CC-16: the current series is an active pill without link, the other series with a course lead to their page" do
      course("mathematiques", series: @series.fetch("d"))
      course("mathematiques", series: @series.fetch("c"))

      get public_level_series_path("tle", "d")

      assert_select "#series_siblings span[aria-current=page]", "Tle D"
      assert_select "#series_siblings a", 1
      assert_select "#series_siblings a[href='/niveaux/tle/c']", "Tle C"
    end

    test "CC-17: more than six courses of a material lead to the material page filtered on the level and the series" do
      8.times { |index| course("mathematiques", name: "Cours #{index}", series: @series.fetch("d")) }

      get public_level_series_path("tle", "d")

      assert_select "#group_mathematiques li", 6
      assert_select "#group_mathematiques_more[href=?]", "/matieres/mathematiques?niveau=tle&serie=d", text: "Voir les 8 fiches de cours"
      assert_select "#group_mathematiques h2 a[href=?]", "/matieres/mathematiques?niveau=tle&serie=d"
    end

    test "CC-18: a pair without course, of its own or common, says its courses are coming, is not indexed and has no pill" do
      course("mathematiques", series: @series.fetch("d"))

      get public_level_series_path("tle", "a1")

      assert_response :success
      assert_select "#series_empty", text: /Les fiches de cours de Tle A1 arrivent bientôt\./
      assert_select "#series_empty a[href='/niveaux/tle']", "Voir la Tle"
      assert_select "head meta[name=robots][content=noindex]"

      get public_level_path("tle")
      assert_select "a[href='/niveaux/tle/a1']", 0
    end

    test "CC-07: the series page links to no content and its cards hold no link nor button" do
      published = course("mathematiques", name: "Suites", series: @series.fetch("d"))
      create_essential(course: published, name: "Fiche des suites")

      get public_level_series_path("tle", "d")

      assert_select "article", 1
      assert_select "article a, article button", 0
      assert_select "a[href^='/courses/'], a[href*='/essentials/'], a[href^='/exercises']", 0
    end

    test "CC-06: neither a draft nor an archived course of the series, nor their count" do
      course("mathematiques", name: "Suites", series: @series.fetch("d"))
      course("mathematiques", name: "Intégrales", series: @series.fetch("d"), status: "draft")
      course("mathematiques", name: "Limites", status: "archived")

      get public_level_series_path("tle", "d")

      assert_equal [ "Suites" ], texts("#series_groups h3")
      assert_select "#group_mathematiques h2", text: /1 fiche de cours/
      assert_no_match(/Intégrales|Limites/, response.body)
    end

    test "CC-08, CC-20: a signed-in teacher reads the same page, without redirection nor shared cache" do
      course("mathematiques", series: @series.fetch("d"))
      sign_in_as create_teacher

      get public_level_series_path("tle", "d")

      assert_response :success
      assert_no_match(/public/, response.headers["Cache-Control"])
      assert_match(/private/, response.headers["Cache-Control"])
      assert_select "#series_cta_top a[href='#{courses_path}']", "Ouvrir le catalogue"
    end
  end
end
