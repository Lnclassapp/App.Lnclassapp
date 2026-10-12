require "application_system_test_case"

# ADR-0055, UDR-0041, PR-04, PR-05, PR-07: a student changes the number in the modal, under the current PIN.
# A wrong PIN stays in the modal without a reload; the change closes the session of a second browser, and the new
# number signs in. The profile page belongs to Lot A: the modal is opened by open_in_modal, over the student home.
class Identity::ProfileContactTest < ApplicationSystemTestCase
  # Until Lot A is merged, a stand-in answers on profile_path, where the change lands; a merged controller is
  # autoloadable, so the stand-in steps aside by itself. Only the toast and the path are asserted, never the page.
  unless Object.const_defined?("Identity::ProfilesController")
    Identity.const_set(:ProfilesController, Class.new(AuthenticatedController) { def show = render(html: "", layout: true, formats: :html) })
  end

  test "a student changes the number with the current PIN, the other session closes, the new number signs in" do
    student = create_student(contact: "0101020304", classroom: create_classroom)
    using_session(:other_phone) do
      sign_in_as student
      assert_current_path student_home_path
    end
    sign_in_as student
    assert_current_path student_home_path

    assert_no_page_reload do
      open_in_modal edit_profile_contact_path
      within "turbo-frame#modal dialog[open]" do
        fill_in "contact_change[current_pin]", with: "1357"
        fill_in "contact_change[contact]", with: "07 11 22 33 44"
        fill_in "contact_change[contact_confirmation]", with: "07 11 22 33 44"
        click_on "Changer mon numéro"

        assert_selector "[role=alert]", text: "Code secret incorrect."
        assert_field "contact_change[current_pin]", with: ""
        assert_field "contact_change[contact]", with: "07 11 22 33 44"
      end
    end

    within "turbo-frame#modal dialog[open]" do
      fill_in "contact_change[current_pin]", with: "2468"
      click_on "Changer mon numéro"
    end

    assert_current_path profile_path, wait: SIGN_IN_WAIT
    assert_toast "Ton numéro est changé."

    using_session(:other_phone) do
      visit student_home_path
      assert_current_path new_session_path
    end

    sign_out
    sign_in_as Struct.new(:contact).new("0711223344")
    assert_current_path student_home_path
  end
end
