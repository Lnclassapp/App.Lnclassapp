require "application_system_test_case"

# ADR-0089 §4.4, UDR-0084 §3.1 : depuis le menu ⋮, une fiche dont il reste des emplacements d'image ne se publie pas, et
# « Tout publier » sur son cours non plus ; le toast d'erreur en donne la raison, sans rechargement de page.
class Catalog::PublishEssentialWithImagesTest < ApplicationSystemTestCase
  SLOTS = "<p>[[image: une pile et une lampe]]</p><p>Le courant circule.</p><p>[[image: un interrupteur ouvert]]</p>".freeze

  def t(key, **) = I18n.t(key, **)

  test "publier une fiche avec deux emplacements est refusé ; elle reste en brouillon" do
    course = create_course(name: "Le circuit électrique")
    essential = create_essential(course:, name: "Le circuit simple", status: "draft", content: SLOTS)
    sign_in_as create_team_member
    visit course_essential_path(course.slug, essential.slug)

    assert_no_page_reload do
      find("button[aria-controls=essential-actions-menu]").click
      click_on t("catalog.content_status.actions.publish")
      assert_toast t("teams.essentials.transition.image_slots_left", count: 2)
      assert_selector "#content_status_essential_#{essential.slug}", text: t("catalog.content_status.draft")
    end
    assert_equal "draft", essential.reload.status
  end

  test "« Tout publier » sur le cours est refusé, nomme la fiche, et rien n'est publié" do
    course = create_course(name: "Électricité", status: "draft")
    ready = create_essential(course:, name: "La pile", status: "draft")
    waiting = create_essential(course:, name: "La lampe", status: "draft", content: SLOTS)
    sign_in_as create_team_member
    visit course_path(course.slug)

    assert_no_page_reload do
      find("button[aria-controls=course-actions-menu]").click
      click_on t("catalog.content_status.actions.publish_all")
      assert_toast t("teams.courses.transition.essential_not_ready", name: "La lampe")
    end
    assert_equal %w[draft draft draft], [ course, ready, waiting ].map { it.reload.status }
  end
end
