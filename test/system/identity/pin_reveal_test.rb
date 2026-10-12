require "application_system_test_case"

# UDR-0051, AP-02 to AP-10: the eye button shows then hides the PIN on the sign-in, on a sign-up and in the profile,
# keeps the focus in the field, is driven by the keyboard, masks the PIN again before a submit (the 422 brings it back
# masked, button still there) — on a desktop and at 390 px, without a JavaScript error.
class Identity::PinRevealTest < ApplicationSystemTestCase
  SHOW = "Afficher le code".freeze
  HIDE = "Masquer le code".freeze

  setup do
    @classroom = create_classroom(name: "6ème 1")
    browser_errors # the browser log is shared by the tests of the process: start from an empty one
  end

  test "sign-in: show then hide the PIN, the focus stays in the field" do
    visit new_session_path
    show_then_hide "session[pin]"
    assert_no_js_errors
  end

  test "sign-in at 390 px: the button sits inside the field, the page does not scroll sideways" do
    with_mobile_viewport do
      visit new_session_path
      assert_button_inside_field "session[pin]"
      show_then_hide "session[pin]"
      assert_no_horizontal_scroll
    end
    assert_no_js_errors
  end

  # IL-08 (ADR-0085): the student sign-up, opened by a classroom link, the classroom already chosen.
  test "student sign-up by link: the PIN is masked again before a failed submit and comes back masked in 422" do
    visit join_classroom_path(@classroom.reload.link_token)
    failed_sign_up_masks_again
    assert_no_js_errors
  end

  test "student sign-up by link at 390 px" do
    with_mobile_viewport do
      visit join_classroom_path(@classroom.reload.link_token)
      assert_button_inside_field "student_registration[pin_confirmation]"
      show_then_hide "student_registration[pin]"
      failed_sign_up_masks_again
      assert_no_horizontal_scroll
    end
    assert_no_js_errors
  end

  test "profile: the three PIN fields of « Changer mon code secret » show and hide one by one" do
    sign_in_as create_teacher
    profile_pin_fields_one_by_one
    assert_no_js_errors
  end

  test "profile at 390 px" do
    teacher = create_teacher
    with_mobile_viewport do
      sign_in_as teacher
      profile_pin_fields_one_by_one
      assert_button_inside_field "pin_change[pin]"
      assert_no_horizontal_scroll
    end
    assert_no_js_errors
  end

  test "keyboard: Tab from the field reaches the button, Enter shows the PIN, Space hides it" do
    visit new_session_path
    field = find_field("session[pin]")
    field.fill_in with: "2468"
    field.send_keys(:tab)

    assert_equal toggle_for("session[pin]"), active_element
    active_element.send_keys(:enter)
    assert_revealed "session[pin]"
    assert_equal toggle_for("session[pin]"), active_element, "au clavier, le focus reste sur le bouton"

    active_element.send_keys(:space)
    assert_masked "session[pin]"
    assert_no_js_errors
  end

  test "the PIN is masked again when the page comes back from the Turbo cache" do
    visit new_session_path
    fill_in "session[pin]", with: "2468"
    toggle_for("session[pin]").click
    assert_revealed "session[pin]"

    click_on I18n.t("identity.sessions.new.forgot_pin")
    assert_selector "#pin-reset-form"
    page.go_back

    assert_selector "#session-form"
    assert_masked "session[pin]"
  end

  private

  def show_then_hide(name)
    field = find_field(name)
    field.fill_in with: "4821"
    assert_masked name

    toggle_for(name).click
    assert_revealed name
    assert_equal field, active_element, "au pointeur, le focus reste dans le champ"
    assert_equal "4821", field.value
    assert_caret_at_end field

    toggle_for(name).click
    assert_masked name
    assert_equal field, active_element
    assert_caret_at_end field
  end

  # The caret stays where it was (after the last digit), even once Chrome has reset it on the change of type.
  def assert_caret_at_end(field)
    caret = page.evaluate_async_script(<<~JS, field)
      const [input, done] = arguments
      requestAnimationFrame(() => requestAnimationFrame(() => done([input.selectionStart, input.selectionEnd])))
    JS

    assert_equal [ 4, 4 ], caret
  end

  def failed_sign_up_masks_again
    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya"
    choose I18n.t("genders.female")
    fill_in "student_registration[contact]", with: "07 01 02 03 04"
    fill_in "student_registration[pin]", with: "4821"
    fill_in "student_registration[pin_confirmation]", with: "1357"
    toggle_for("student_registration[pin]").click
    toggle_for("student_registration[pin_confirmation]").click
    assert_revealed "student_registration[pin]"
    # Turbo stops the submit event at the document; turbo:submit-start follows it, before the request leaves.
    page.execute_script(<<~JS)
      document.addEventListener("turbo:submit-start", () => {
        window.pinTypesAtSubmit = [...document.querySelectorAll("[data-password-reveal-target=input]")].map((input) => input.type)
      }, { once: true })
    JS

    assert_no_page_reload do
      click_on I18n.t("classroom.student_registrations.form.submit")
      assert_selector "#student_registration_pin_confirmation_error"
    end

    assert_equal %w[password password], page.evaluate_script("window.pinTypesAtSubmit")
    %w[student_registration[pin] student_registration[pin_confirmation]].each do |name|
      assert_masked name
      assert_field name, with: ""
    end
  end

  def profile_pin_fields_one_by_one
    open_in_modal edit_profile_pin_path
    within "turbo-frame#modal dialog[open]" do
      names = %w[pin_change[current_pin] pin_change[pin] pin_change[pin_confirmation]]
      names.each { fill_in it, with: "2468" }
      names.each do |name|
        toggle_for(name).click
        assert_revealed name
        (names - [ name ]).each { assert_masked it }
        toggle_for(name).click
        assert_masked name
      end
    end
  end

  def toggle_for(name)
    find("button[aria-controls='#{find_field(name)[:id]}']")
  end

  def assert_masked(name)
    assert_equal "password", find_field(name)[:type]
    toggle = toggle_for(name)
    assert_equal "false", toggle["aria-pressed"]
    assert_equal SHOW, toggle["aria-label"]
    toggle.assert_selector "span[data-icon=eye]", visible: true
    toggle.assert_no_selector "span[data-icon=eye-slash]", visible: true
  end

  def assert_revealed(name)
    assert_equal "text", find_field(name)[:type]
    toggle = toggle_for(name)
    assert_equal "true", toggle["aria-pressed"]
    assert_equal HIDE, toggle["aria-label"]
    toggle.assert_selector "span[data-icon=eye-slash]", visible: true
    toggle.assert_no_selector "span[data-icon=eye]", visible: true
  end

  def active_element
    page.active_element
  end

  # UDR-0051: a 48 × 48 px target, inside the field, on its right.
  def assert_button_inside_field(name)
    field = rect(find_field(name))
    button = rect(toggle_for(name))

    assert_operator button["width"], :>=, 48
    assert_operator button["height"], :>=, 48
    assert_in_delta field["right"], button["right"], 1
    assert_operator button["top"], :>=, field["top"] - 1
    assert_operator button["bottom"], :<=, field["bottom"] + 1
  end

  def rect(node)
    page.evaluate_script("arguments[0].getBoundingClientRect().toJSON()", node)
  end

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end

  # A 422 is the expected answer of a failed form: Chrome logs it as a failed resource, it is no JavaScript error.
  def assert_no_js_errors
    errors = browser_errors.reject { it.include?("Failed to load resource") }

    assert_empty errors, "erreurs JavaScript :\n#{errors.join("\n")}"
  end

  def browser_errors
    page.driver.browser.logs.get(:browser).select { it.level == "SEVERE" }.map(&:message)
  end
end
