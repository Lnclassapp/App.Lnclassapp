require "test_helper"

# ADR-0105 §4.5, UDR-0129 §3.3, ADR-0113: the image cited by a notion is read in the lesson page, in the « Fiche de révision »,
# served by Lnclass, lazily and at its dimensions; the student of the level can then fetch it.
class Catalog::RevisionImagesTest < ActionDispatch::IntegrationTest
  DESCRIPTION = "une pile reliée à une lampe".freeze

  setup do
    @course = create_course(name: "Électricité")
    @essential = create_essential(course: @course, name: "Le circuit", content: "<p>Un circuit fermé.</p>")
    @image = create_essential_image(essential: @essential, alt: DESCRIPTION)
    @essential.update!(content: %(<p>Un circuit fermé.</p><action-text-attachment sgid="#{@image.attachable_sgid}" ) +
                                %(content-type="#{@image.content_type}"></action-text-attachment><p>La lampe brille.</p>))
    @student = create_student_for(@course)
  end

  test "the lesson page shows the image of a notion, with its alternative text, lazily, at its dimensions" do
    sign_in_as @student

    get course_path(@course.slug)

    assert_response :success
    assert_select "#fiche-de-revision figure img[src=?][alt=?][loading=lazy][width=?][height=?]",
                  essential_image_path(@image.public_id), DESCRIPTION, @image.width.to_s, @image.height.to_s
    assert_select "#fiche-de-revision", text: /Un circuit fermé\.\s*La lampe brille\./m
    get essential_image_path(@image.public_id)
    assert_response :success
  end
end
