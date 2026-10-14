require "application_system_test_case"

# ADR-0089, UDR-0084 §3.1 and §3.3 — Lot A of images-dans-les-cours. A Contenu member opens the sheet's « Modifier », puts
# the cursor in the slot « [[image: …]] » left by the import and inserts an image: it replaces the slot, its text
# alternative is the slot's description, the counter is gone. The student of the level then reads the image in the sheet,
# served by Lnclass, lazily. The refusals (403, 422, 31st image, 404 out of level, draft or replaced) are proven at the
# controller level: test/controllers/teams/essential_images_controller_test.rb, test/controllers/catalog/essential_images_controller_test.rb.
class Catalog::EssentialImagesTest < ApplicationSystemTestCase
  # Shrinking a photo, then sending it, under a loaded full suite.
  UPLOAD_WAIT = 20
  DESCRIPTION = "une pile reliée à une lampe".freeze

  setup do
    @course = create_course(name: "Électricité")
    @essential = create_essential(course: @course, name: "Le circuit",
                                  content: "<p>Un circuit fermé.</p><p>[[image: #{DESCRIPTION}]]</p><p>La lampe brille.</p>")
  end

  def tf(key, **) = I18n.t("teams.essentials.form.#{key}", **)

  # The cursor inside the slot paragraph, as a click on it would put it.
  def cursor_in_slot
    page.execute_script(<<~JS)
      const element = document.querySelector("trix-editor#essential_content")
      const document_ = element.editor.getDocument()
      const index = document_.getBlocks().findIndex((block) => block.toString().startsWith("[[image:"))
      element.focus()
      element.editor.setSelectedRange(document_.positionFromLocation({ index, offset: 3 }))
    JS
  end

  test "the team inserts an image in place of a slot, its alt prefilled; the student of the level sees it, lazily" do
    sign_in_as create_team_member(team_role: "content")
    visit course_essential_path(@course.slug, @essential.slug)
    click_menu_action("#essential_team_actions", I18n.t("catalog.essentials.show.edit"))

    within "turbo-frame#modal dialog[open]" do
      assert_selector "#essential_image_slots", text: tf("slots_left", count: 1)
      assert_selector "#essential_image_slots li", text: tf("slot", description: DESCRIPTION)
      assert_selector "#essential_insert_image"
      cursor_in_slot
      attach_file "essential_image_files", file_fixture("photos/photo.jpg").to_s, make_visible: true

      field = find("#essential_image_alts li:not([hidden]) input[name^='essential[image_alts]']", wait: UPLOAD_WAIT)
      assert_equal DESCRIPTION, field.value
      assert_selector "#essential_image_slots", visible: :hidden
      click_on I18n.t("teams.essentials.edit.submit")
    end
    assert_toast I18n.t("teams.essentials.update.updated", name: "Le circuit")

    image = Orm::EssentialImage.sole
    assert_equal [ @essential.id, DESCRIPTION ], [ image.essential_id, image.alt ]
    body = @essential.reload.content.body.to_html
    assert_not_includes body, "[[image:"
    assert_includes body, "Un circuit fermé."

    using_session(:student) do
      sign_in_as create_student_for(@course)
      visit course_essential_path(@course.slug, @essential.slug)
      within "#essential_content" do
        assert_selector "figure img[src='#{essential_image_path(image.public_id)}'][alt='#{DESCRIPTION}'][loading=lazy]" \
                        "[width='#{image.width}'][height='#{image.height}']"
      end
      assert page.evaluate_script("document.querySelector('#essential_content img').naturalWidth > 0"), "l'image est servie"
    end
  end
end
