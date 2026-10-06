require "test_helper"

# PH-01, PH-05, UDR-0047: the photo replaces the initials wherever the avatar of that account is shown — account menu,
# sidebar, profile card, class list, account found by the team — at its authenticated, versioned address.
class Identity::ProfilePhotoDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom
    @student = attach_photo(create_student(classroom: @classroom, first_name: "Aya", last_name: "Koné", contact: "0511223344"))
    @src = account_photo_path(@student.public_id, v: Queries::Identity::PhotoVersions.for(user_ids: [ @student.id ])[@student.id])
  end

  test "the account menu, the sidebar and the profile card show the photo; « Changer ma photo » opens the modal" do
    sign_in_as @student

    get profile_path

    assert_select "header button[aria-controls=account-menu] img.ui-avatar[alt='Aya Koné'][src='#{@src}']"
    assert_select "aside img[alt='Aya Koné'][src='#{@src}']"
    assert_select "#profile_information" do
      # UDR-0041, amendment of 2026-10-02: for the student, the avatar is the value of the « Photo » row, the
      # sentence is left to screen readers.
      assert_select "img.size-14[alt='Aya Koné'][src='#{@src}']", count: 1
      assert_select "dt", "Photo"
      assert_select "dd span[aria-hidden=true] img.size-14[src='#{@src}']"
      assert_select "dd span.sr-only", "Ta photo remplace tes initiales."
      assert_select "a[href='#{edit_profile_photo_path}'][data-turbo-frame=modal]", text: /Changer ma photo/
    end
  end

  test "without a photo, the initials stay and the profile offers to add one" do
    sign_in_as create_student(first_name: "Awa", last_name: "Traoré")

    get profile_path

    assert_select "header button[aria-controls=account-menu] [role=img][aria-label='Awa Traoré']", text: "AT"
    assert_select "header img[src*='/photo']", 0
    assert_select "#profile_information dd span[aria-hidden=true] [role=img][aria-label='Awa Traoré']", text: "AT"
    assert_select "#profile_information dd span.sr-only", "Aucune photo : tes initiales s'affichent."
    assert_select "#profile_information a[href='#{edit_profile_photo_path}']", text: /Ajouter une photo/
  end

  test "the teacher sees the photo in the class list, the team on the account it finds" do
    sign_in_as create_teacher(classrooms: [ @classroom ])
    get classroom_path(@classroom.public_id)

    assert_select "#student_#{@student.public_id} img[alt='Aya Koné'][src='#{@src}']"
    sign_out

    sign_in_as create_team_member
    get teams_account_lookup_path(contact: "0511223344")

    assert_select "#account-lookup-result img[alt='Aya Koné'][src='#{@src}']"
  end
end
