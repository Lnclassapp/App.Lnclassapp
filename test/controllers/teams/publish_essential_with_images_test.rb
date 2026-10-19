require "test_helper"

# ADR-0105 §4.4, UDR-0129 §3.1 : une fiche avec un emplacement d'image restant ne se publie pas, ni seule ni par « Tout
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

  def illustrated_essential(alt:)
    essential = create_essential(course: @course, status: "draft", content: "<p>Texte.</p>")
    image = create_essential_image(essential:, alt:)
    essential.update!(content: %(<p>Texte.</p><action-text-attachment sgid="#{image.attachable_sgid}" ) +
                               %(content-type="#{image.content_type}"></action-text-attachment>))
    [ essential, image ]
  end

  # PRD §3 : une image sans texte de remplacement est marquée « À compléter » et la fiche ne se publie pas.
  test "une image sans texte de remplacement : badge « À compléter » dans le formulaire, publication refusée" do
    essential, image = illustrated_essential(alt: nil)
    sign_in_as @member

    get edit_teams_essential_path(essential.slug), headers: { "Turbo-Frame" => "modal" }
    assert_select "li#article_image_#{image.public_id} span:not([hidden])", text: I18n.t("teams.articles.form.image_alt_missing")

    patch publish_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]",
                  text: including(I18n.t("teams.essentials.transition.image_alts_blank"))
    assert_equal "draft", essential.reload.status
  end

  test "un emplacement mal écrit (dans une liste) refuse la publication et le dit" do
    essential = create_essential(course: @course, status: "draft", content: "<ul><li>[[image: une pile]]</li></ul>")
    sign_in_as @member

    patch publish_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]",
                  text: including(I18n.t("teams.essentials.transition.image_slots_malformed", count: 1))
    assert_equal "draft", essential.reload.status
  end

  # Menace n° 13 : 182 000 caractères de « <span title="<p>"> » sont sous le plafond de 200 Ko et font tomber le motif en délai.
  HOSTILE = %(<span title="<p>">x</span>) * 7_000

  test "un texte trop complexe à relire refuse la publication avec son propre message, journalisé avec le slug, sans le contenu" do
    essential = create_essential(course: @course, status: "draft", content: HOSTILE)
    sign_in_as @member

    logs = capture_log { patch publish_teams_essential_path(essential.slug), as: :turbo_stream }

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]",
                  text: including(I18n.t("teams.essentials.transition.image_slots_unreadable"))
    assert_equal "draft", essential.reload.status
    assert_includes logs, "[Teams::EssentialsController] image_slots_unreadable slug=#{essential.slug}"
    assert_not_includes logs, "span title"
  end

  test "« Tout publier » un cours dont une fiche est trop complexe à relire la nomme avec son propre message, et journalise" do
    course = create_course(name: "Électricité", status: "draft")
    essential = create_essential(course:, name: "La lampe", status: "draft", content: HOSTILE)
    sign_in_as @member

    logs = capture_log { patch publish_all_teams_course_path(course.slug), as: :turbo_stream }

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]",
                  text: including(I18n.t("teams.courses.transition.essential_unreadable", name: "La lampe"))
    assert_equal %w[draft draft], [ course, essential ].map { it.reload.status }
    assert_includes logs, "[Teams::CoursesController] image_slots_unreadable slug=#{course.slug} name=\"La lampe\""
  end

  test "« Tout publier » sur une fiche trop complexe à relire donne le message de la fiche" do
    essential = create_essential(course: @course, status: "draft", content: HOSTILE)
    sign_in_as @member

    logs = capture_log { patch publish_all_teams_essential_path(essential.slug), as: :turbo_stream }

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(I18n.t("teams.essentials.transition.image_slots_unreadable"))
    assert_includes logs, "[Teams::EssentialsController] image_slots_unreadable slug=#{essential.slug}"
  end

  # ADR-0105 §4.4 : « Tout publier » dit pourquoi un exercice reste en brouillon quand c'est une image qui lui manque.
  test "« Tout publier » : un exercice dont une question attend son image reste en brouillon, avec un message dédié" do
    essential = create_essential(course: @course, status: "draft")
    waiting = create_exercise(essential:, status: "draft")
    waiting.questions.first.update!(image_description: "Un circuit simple")
    incomplete = create_exercise(essential:, status: "draft", questions: 0)
    sign_in_as @member

    patch publish_all_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :success
    assert_equal %w[published draft draft], [ essential, waiting, incomplete ].map { it.reload.status }
    assert_select "turbo-stream[action=append][target=toasts]", text: including(I18n.t("teams.publish_cascade.skipped_images", count: 1))
    assert_select "turbo-stream[action=append][target=toasts]", text: including(I18n.t("teams.publish_cascade.skipped", count: 1))
  end

  # ADR-0074 §4.2, ADR-0105 §4.4 : une fiche en ligne ne perd pas un texte de remplacement par une modification.
  test "modifier une fiche publiée en vidant le texte de remplacement d'une image est refusé (422), rien n'est écrit" do
    essential = create_essential(course: @course, status: "published", content: "<p>Texte.</p>")
    image = create_essential_image(essential:, alt: "Une pile")
    content = %(<p>Texte.</p><action-text-attachment sgid="#{image.attachable_sgid}" content-type="#{image.content_type}"></action-text-attachment>)
    essential.update!(content:)
    sign_in_as @member

    patch teams_essential_path(essential.slug), params: { essential: { name: "Autre nom", content:, image_alts: { image.public_id => " " } } },
                                                as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "li#article_image_#{image.public_id}", text: including(I18n.t("activemodel.errors.models.dtos/catalog/essential_input.image_alt_blank", number: 1))
    assert_equal "Une pile", image.reload.alt
    assert_not_equal "Autre nom", essential.reload.name

    patch teams_essential_path(essential.slug), params: { essential: { name: "Autre nom", content:, image_alts: { image.public_id => "Une lampe" } } },
                                                as: :turbo_stream
    assert_response :success
    assert_equal "Une lampe", image.reload.alt
  end

  test "modifier une fiche publiée avec un texte trop complexe à relire est refusé (422) et journalisé avec le slug" do
    essential = create_essential(course: @course, status: "published")
    sign_in_as @member

    logs = capture_log do
      patch teams_essential_path(essential.slug), params: { essential: { name: "Autre nom", content: HOSTILE } }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_includes logs, "[Teams::EssentialsController] image_slots_unreadable slug=#{essential.slug}"
    assert_not_equal "Autre nom", essential.reload.name
  end

  test "une fiche sans emplacement se publie comme avant" do
    essential = create_essential(course: @course, status: "draft", content: "<p>Voir [[image: ceci]] dans la phrase.</p>")
    sign_in_as @member

    patch publish_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :success
    assert_equal "published", essential.reload.status
  end
end
