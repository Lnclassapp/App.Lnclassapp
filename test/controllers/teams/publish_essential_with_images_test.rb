require "test_helper"

# ADR-0089 §4.4, UDR-0084 §3.1 : une fiche avec un emplacement d'image restant ne se publie pas, ni seule ni par « Tout
# publier » ; le refus (422) en donne la raison, nombre ou fiche nommée, et rien n'est écrit.
class Teams::PublishEssentialWithImagesTest < ActionDispatch::IntegrationTest
  SLOTS = "<p>[[image: une pile et une lampe]]</p><p>Texte.</p><p>[[image: un interrupteur ouvert]]</p>".freeze

  setup do
    @member = create_team_member
    @course = create_course(name: "Le circuit électrique")
  end

  def including(text) = /#{Regexp.escape(text)}/

  test "publier une fiche avec deux emplacements est refusé avec leur nombre, et la fiche reste en brouillon" do
    essential = create_essential(course: @course, status: "draft", content: SLOTS)
    sign_in_as @member

    patch publish_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]",
                  text: including(I18n.t("teams.essentials.transition.image_slots_left", count: 2))
    assert_select "turbo-stream[action=replace]", 0
    assert_equal "draft", essential.reload.status
    assert_not Orm::AuditEvent.exists?(action: "content.published")
  end

  test "sans Turbo, le refus revient avec le message au pluriel" do
    essential = create_essential(course: @course, status: "draft", content: "<p>[[image: une pile]]</p>")
    sign_in_as @member

    patch publish_teams_essential_path(essential.slug)

    assert_response :see_other
    assert_equal I18n.t("teams.essentials.transition.image_slots_left", count: 1), flash[:alert]
  end

  test "« Tout publier » un cours dont une fiche n'est pas prête ne publie rien et nomme la fiche" do
    course = create_course(name: "Électricité", status: "draft")
    ready = create_essential(course:, name: "La pile", status: "draft")
    waiting = create_essential(course:, name: "La lampe", status: "draft", content: SLOTS)
    sign_in_as @member

    patch publish_all_teams_course_path(course.slug), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]",
                  text: including(I18n.t("teams.courses.transition.essential_not_ready", name: "La lampe"))
    assert_equal %w[draft draft draft], [ course, ready, waiting ].map { it.reload.status }
    assert_not Orm::AuditEvent.exists?
  end

  test "« Tout publier » sur la fiche elle-même donne le nombre d'emplacements" do
    essential = create_essential(course: @course, status: "draft", content: SLOTS)
    sign_in_as @member

    patch publish_all_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]",
                  text: including(I18n.t("teams.essentials.transition.image_slots_left", count: 2))
    assert_equal "draft", essential.reload.status
  end

  test "une fiche sans emplacement se publie comme avant" do
    essential = create_essential(course: @course, status: "draft", content: "<p>Voir [[image: ceci]] dans la phrase.</p>")
    sign_in_as @member

    patch publish_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :success
    assert_equal "published", essential.reload.status
  end
end
