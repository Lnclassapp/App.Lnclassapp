require "application_system_test_case"

# carte-profil-eleve (UDR-0132 §3.1, amended), CA-5 and CA-6: on a computer, the student's sidebar opens on the same profile card as
# the teacher's (UDR enseignant §3.14) — same place, same width, same height — and a long name never widens the sidebar. On a phone
# the sidebar is not shown at all. The markup of each state is proved in test/views/shared/navigation/sidebar_test.rb.
class Identity::StudentSidebarProfileCardTest < ApplicationSystemTestCase
  DESKTOP_VIEWPORT = [ 1280, 900 ].freeze
  CARD = "aside > div.rounded-card".freeze

  setup do
    @classroom = create_classroom(name: "3ème B", school: create_school(name: "Lycée Moderne de Cocody", sigle: "LMC"))
  end

  test "CA-5: on a computer, the student's card has the teacher's frame; avatar, name, class and sigle, then the navigation" do
    teacher = create_teacher(classrooms: [ @classroom ], first_name: "Koffi", last_name: "Yao")
    student = create_student(classroom: @classroom, first_name: "Awa", last_name: "Koné")

    with_mobile_viewport(DESKTOP_VIEWPORT) do
      sign_in_as teacher
      teacher_card = find(CARD).rect
      sign_out

      sign_in_as student
      within(CARD) do
        assert_selector "[role=img][aria-label='Awa Koné']", text: "AK"
        assert_selector "p", text: "Awa Koné"
        assert_selector "p", text: "3ème B · LMC"
      end
      card = find(CARD).rect
      assert_equal [ teacher_card.x, teacher_card.y, teacher_card.width, teacher_card.height ], [ card.x, card.y, card.width, card.height ]
      assert_operator find("aside > nav").rect.y, :>, card.y + card.height, "la navigation suit la carte"
    end
  end

  test "CA-6: a long name is cut on one line inside the sidebar; on a phone the sidebar stays hidden" do
    create_student(classroom: @classroom, first_name: "Marie-Christelle Adjoua", last_name: "Kouassi-N'Guessan de Bingerville").then { sign_in_as it }

    with_mobile_viewport(DESKTOP_VIEWPORT) do
      visit courses_path
      name = find("#{CARD} p.font-medium")
      assert_operator name.rect.height, :<, 2 * page.evaluate_script("parseFloat(getComputedStyle(arguments[0]).lineHeight)", name)
      assert page.evaluate_script("arguments[0].scrollWidth > arguments[0].clientWidth", name), "le nom est tronqué"
      assert_operator find(CARD).rect.x + find(CARD).rect.width, :<=, find("aside").rect.width
    end

    with_mobile_viewport { assert_no_selector "aside", visible: :visible }
  end
end
