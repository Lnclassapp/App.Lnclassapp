require "test_helper"

module Catalog
  class ContentStatusHelperTest < ActionView::TestCase
    helper ComponentsHelper

    def course(status) = Entities::Catalog::Course.new(slug: "genetique", name: "Génétique", status:)

    test "le badge nomme chaque statut" do
      render html: safe_join(%w[draft published archived].map { content_status_badge(it) })

      assert_equal [ "Brouillon — visible uniquement par l'équipe", "Publié", "Archivé" ], css_select("span.whitespace-nowrap").map(&:text)
      assert_raises(KeyError) { content_status_badge("deleted") }
    end

    test "le panneau d'un brouillon propose de publier, celui d'un contenu publié d'archiver" do
      render html: content_status_panel(record: course("draft"))

      assert_dom "div#content_status_course_genetique" do
        assert_dom "form[action='/teams/courses/genetique/publish'] input[name='_method'][value='patch']"
        assert_dom "button", text: "Publier"
        assert_dom "form", count: 1
      end

      render html: content_status_panel(record: course("published"))

      assert_dom "form[action='/teams/courses/genetique/archive'] button", text: "Archiver"
    end

    test "une fiche et un exercice sont adressés par leur slug et leur public_id ; un archivé se republie" do
      essential = Entities::Catalog::Essential.new(slug: "genetique-mitose", name: "Mitose", status: "archived")
      exercise = Entities::Assessment::Exercise.new(public_id: "Ab12Cd34Ef56Gh", title: "Défi", status: "published",
                                                    questions: [], parents_published: true)

      render html: safe_join([ content_status_panel(record: essential), content_status_panel(record: exercise) ])

      assert_dom "#content_status_essential_genetique-mitose form[action='/teams/essentials/genetique-mitose/publish']"
      assert_dom "#content_status_exercise_Ab12Cd34Ef56Gh form[action='/teams/exercises/Ab12Cd34Ef56Gh/archive']"
    end
  end
end
