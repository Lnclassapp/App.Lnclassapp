require "application_system_test_case"

# ADR-0105 §4.4, UDR-0129 §3.1 : « Tout publier » sur un cours dont une fiche garde des emplacements d'image ne publie rien ; le toast d'erreur en donne la raison, sans rechargement de page.
class Catalog::PublishEssentialWithImagesTest < ApplicationSystemTestCase
  SLOTS = "<p>[[image: une pile et une lampe]]</p><p>Le courant circule.</p><p>[[image: un interrupteur ouvert]]</p>".freeze

  def t(key, **) = I18n.t(key, **)

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
