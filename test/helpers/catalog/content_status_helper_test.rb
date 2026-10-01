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

    # Épuration des en-têtes (2026-09-30) : le panneau ne montre que le statut ; les transitions sont des entrées du menu ⋮.
    test "le panneau ne montre que le statut ; un brouillon propose de publier dans le menu, un contenu publié d'archiver" do
      render html: safe_join([ content_status_panel(record: course("draft")), content_transition_items(record: course("draft")) ])

      assert_dom "div#content_status_course_genetique", text: /Brouillon/ do
        assert_dom "form, button, a", count: 0
      end
      assert_dom "div#content_transitions_course_genetique.contents[role=none]" do
        assert_dom "a[role=menuitem][href='/teams/courses/genetique/publish'][data-turbo-method=patch]", text: "Publier"
        assert_dom "a[data-action='dropdown#dismiss']", count: 1
        assert_dom "a", count: 1
      end

      render html: content_transition_items(record: course("published"))

      assert_dom "a[role=menuitem][href='/teams/courses/genetique/archive'][data-turbo-method=patch]", text: "Archiver"
    end

    test "une fiche et un exercice sont adressés par leur slug et leur public_id ; un archivé se republie" do
      essential = Entities::Catalog::Essential.new(slug: "genetique-mitose", name: "Mitose", status: "archived")
      exercise = Entities::Assessment::Exercise.new(public_id: "Ab12Cd34Ef56Gh", title: "Défi", status: "published",
                                                    questions: [], parents_published: true)

      render html: safe_join([ content_status_panel(record: essential), content_transition_items(record: essential),
                               content_status_panel(record: exercise), content_transition_items(record: exercise) ])

      assert_dom "#content_status_essential_genetique-mitose", text: /Archivé/
      assert_dom "#content_transitions_essential_genetique-mitose a[href='/teams/essentials/genetique-mitose/publish']"
      assert_dom "#content_status_exercise_Ab12Cd34Ef56Gh", text: /Publié/
      assert_dom "#content_transitions_exercise_Ab12Cd34Ef56Gh a[href='/teams/exercises/Ab12Cd34Ef56Gh/archive']"
    end
  end
end
