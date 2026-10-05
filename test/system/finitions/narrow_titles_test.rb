require "application_system_test_case"

# suites-inscription-direction (3), UDR-0054 : à 390 px, chaque page d'inscription montre son titre principal (h1), qui
# n'était jusqu'ici que dans la colonne des grands écrans.
class FinitionsNarrowTitlesTest < ApplicationSystemTestCase
  test "at 390 px, the four sign-up pages show their h1" do
    invitation = create_invitation(kind: "school_staff", school: create_school)
    classroom = create_classroom

    with_mobile_viewport do
      [ new_school_staff_registration_path, new_teacher_registration_path, invitation_path(invitation.token),
        join_classroom_path(classroom.join_code) ].each do |path|
        visit path

        assert_selector "h1", visible: true, count: 1
      end
    end
  end
end
