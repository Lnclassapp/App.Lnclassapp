require "application_system_test_case"

# UDR-0005 et UDR-0006 — chaque composant de /design dans ses variantes et ses états, rendu par un vrai navigateur.
class DesignSystemTest < ApplicationSystemTestCase
  TOKENS = {
    "ink" => "rgb(38, 38, 38)", "paper" => "rgb(250, 248, 244)", "brand" => "rgb(0, 160, 255)",
    "brand-strong" => "rgb(0, 112, 179)", "teacher" => "rgb(255, 138, 0)", "school" => "rgb(27, 54, 93)",
    "team" => "rgb(123, 58, 237)", "success" => "rgb(24, 114, 63)", "error" => "rgb(200, 50, 43)"
  }.freeze

  setup { visit design_path }

  test "colour tokens compile to the landing palette, fonts are served by the app" do
    TOKENS.each do |token, rgb|
      swatch = find("[data-token='#{token}'] div")

      assert_equal rgb, css(swatch, "background-color"), token
    end
    assert_match(/DM Sans/, find("body").style("font-family")["font-family"])
    assert_match(/Bricolage Grotesque/, find("#colors-title").style("font-family")["font-family"])
    assert page.evaluate_script("document.fonts.check('16px \"DM Sans\"')")
  end

  test "icons render in every variant and size, labelled when asked" do
    within("[data-example=icon-variants]") { assert_selector "svg[aria-hidden=true]", count: 3 }
    within("[data-example=icon-sizes]") do
      assert_equal %w[16px 20px 24px 32px], %w[sm md lg xl].map { |size| find("[data-size=#{size}] svg").style("width")["width"] }
      assert_selector "svg[role=img][aria-label='#{t('design.index.icons.labelled')}']"
    end
  end

  test "buttons in every variant, size and state" do
    within("[data-example=button-variants]") do
      assert_equal "rgb(38, 38, 38)", css(find("[data-variant=primary]"), "background-color")
      assert_equal "rgb(0, 160, 255)", css(find("[data-variant=brand]"), "background-color")
      assert_equal "rgb(200, 50, 43)", css(find("[data-variant=danger]"), "background-color")
      assert_selector "button[data-variant]", count: 5
    end
    within("[data-example=button-sizes]") do
      heights = %w[sm md lg].map { |size| find("[data-size=#{size}]").style("height")["height"].to_f }

      assert_equal [ 40.0, 48.0, 56.0 ], heights
    end
    within("[data-example=button-states]") do
      assert_selector "button[data-state=icon] svg"
      assert_selector "button[data-state=disabled][disabled]"
      assert_selector "button[data-state=loading][disabled][aria-busy=true] svg.animate-spin"
      assert_selector "a[data-state=link][href]"
      assert_selector "a[data-state=disabled-link][aria-disabled=true]:not([href])"
    end
  end

  test "badges for every tone, role and subject category" do
    assert_selector "[data-example=badge-tones] [data-tone]", count: ComponentsHelper::BADGE_TONES.size
    assert_selector "[data-example=badge-roles] [data-role]", count: 4
    within("[data-example=badge-subjects]") do
      assert_equal "rgb(229, 245, 255)", css(find("[data-category=science] > span"), "background-color")
      assert_equal "rgb(242, 238, 231)", css(find("[data-category=unknown] > span"), "background-color")
    end
  end

  test "fields at rest and in error are wired for assistive technologies" do
    within("[data-example=field-valid]") do
      assert_selector "input#sample_email[aria-describedby=sample_email_hint]"
      assert_no_selector "[aria-invalid]"
    end
    within("[data-example=field-invalid]") do
      assert_selector "input#invalid_sample_name[aria-invalid=true][aria-describedby=invalid_sample_name_error]"
      assert_selector "#invalid_sample_email[aria-describedby='invalid_sample_email_hint invalid_sample_email_error']"
      assert_selector "#invalid_sample_bio[disabled]"
      assert_equal "rgb(200, 50, 43)", css(find("#invalid_sample_name"), "border-top-color")
    end
  end

  test "the modal opens, closes by its button, by Escape and by the backdrop" do
    dialog = "dialog#demo-modal"
    click_on t("design.index.modal.open")

    assert_selector "#{dialog}[open]"
    assert_equal "hidden", page.evaluate_script("getComputedStyle(document.documentElement).overflow")

    find("#{dialog} button[aria-label='#{t('components.modal.close')}']").click

    assert_no_selector "#{dialog}[open]"

    # Wait for the modal to be open before closing it: on a loaded machine, the key or the click came too early.
    click_on t("design.index.modal.open")
    find("#{dialog}[open]").send_keys(:escape)

    assert_no_selector "#{dialog}[open]"

    click_on t("design.index.modal.open")
    assert_selector "#{dialog}[open]"
    page.driver.browser.action.move_to_location(5, 5).click.perform

    assert_no_selector "#{dialog}[open]"
  end

  test "the dropdown follows the menu button pattern" do
    button = find("button[aria-controls=demo-menu]")
    button.click

    assert_selector "#demo-menu:not([hidden])"
    assert_equal "true", button["aria-expanded"]
    assert_equal t("design.index.dropdown.edit"), active_text

    send_to_active :down
    send_to_active :down

    assert_equal t("design.index.dropdown.delete"), active_text, "l'entrée inactive est sautée"

    send_to_active :down

    assert_equal t("design.index.dropdown.edit"), active_text, "la navigation boucle"

    send_to_active :end

    assert_equal t("design.index.dropdown.delete"), active_text

    send_to_active :escape

    assert_selector "#demo-menu[hidden]", visible: :all
    assert_equal "demo-menu", page.evaluate_script("document.activeElement.getAttribute('aria-controls')")

    button.click
    find("#typography-title").click

    assert_selector "#demo-menu[hidden]", visible: :all
  end

  test "tabs switch by click and by keyboard" do
    within("[data-example=tabs]") do
      find("[role=tab]", text: t("design.index.tabs.community")).click

      assert_selector "#demo-tabs-panel-community", text: t("design.index.tabs.community_body")
      assert_no_selector "#demo-tabs-panel-steering"

      send_to_active :right

      assert_selector "#demo-tabs-tab-academy[aria-selected=true][tabindex='0']"
      send_to_active :right

      assert_selector "#demo-tabs-tab-steering[aria-selected=true]"
      send_to_active :left

      assert_selector "#demo-tabs-tab-academy[aria-selected=true]"
      send_to_active :home

      assert_selector "#demo-tabs-tab-steering[aria-selected=true]"
      send_to_active :end

      assert_selector "#demo-tabs-panel-academy", text: t("design.index.tabs.academy_body")
    end
  end

  test "toasts arrive by Turbo Stream, keep their message and can be dismissed" do
    ComponentsHelper::TOAST_TYPES.each_key do |type|
      find("button[data-stream=#{type}]").click

      assert_selector "#toasts [data-toast-type=#{type}]", text: t("components.toast.titles.#{type}")
    end
    assert_selector "#toasts [role=alert][data-toast-type=error]", text: /\d{2}:\d{2}:\d{2}/

    find("#toasts [data-toast-type=error] button[aria-label='#{t('components.toast.dismiss')}']").click

    assert_no_selector "#toasts [data-toast-type=error]"
  end

  # Lot B4: a stream that sends a toast and a refresh lost the toast, since the morph removed it from #toasts.
  test "a toast sent with a refresh survives the morph of the page" do
    find("button[data-stream=success]").click
    assert_selector "#toasts [data-toast-type=success]"
    execute_script("addEventListener('turbo:morph', () => document.body.dataset.morphed = 'yes', { once: true })")
    execute_script("Turbo.renderStreamMessage('<turbo-stream action=\"refresh\"></turbo-stream>')")

    assert_selector "body[data-morphed=yes]"
    assert_selector "#toasts [data-toast-type=success]", text: t("components.toast.titles.success")
  end

  # Lot B1: a refresh morphs the formula back to its raw source, and the math controller, still connected, did not
  # render it again. It now renders again after every morph.
  test "a formula stays rendered after the morph of the page" do
    assert_selector "#design_math .katex"
    execute_script("addEventListener('turbo:morph', () => document.body.dataset.morphed = 'yes', { once: true })")
    execute_script("Turbo.renderStreamMessage('<turbo-stream action=\"refresh\"></turbo-stream>')")

    assert_selector "body[data-morphed=yes]"
    assert_selector "#design_math .katex"
    assert_no_text "$A ="
  end

  # Lot S1: at the top, a toast covered the actions of the page header. On a desktop it now sits at the bottom;
  # on a phone it stays at the top, since the bottom bar holds the navigation.
  test "a toast never covers the page header on a desktop, and stays above the bottom bar on a phone" do
    toast_top = lambda do
      find("button[data-stream=success]").click
      find("#toasts [data-toast-type=success]", match: :first).evaluate_script("this.getBoundingClientRect().top")
    end

    assert_operator toast_top.call, :>, evaluate_script("window.innerHeight / 2")

    with_mobile_viewport do
      assert_operator toast_top.call, :<, evaluate_script("window.innerHeight / 2")
    end
  end

  # Lot B2: builds/trix.css sits in no layer and is linked inside the edit form, after application.css. It erased the
  # rich text typography (`.trix-content * { margin: 0 }`) and brought back the file button that V1 refuses.
  test "the rich text typography and the hidden file button win over trix.css, even when it comes last" do
    page.evaluate_async_script(<<~JS, ActionController::Base.helpers.stylesheet_path("trix"))
      const [href, done] = arguments
      document.body.insertAdjacentHTML("beforeend", `
        <div class="trix-content"><p id="rich-first">Un</p><ul id="rich-list"><li id="rich-item">Deux</li></ul></div>
        <trix-toolbar><span class="trix-button-group" data-trix-button-group="file-tools" id="file-tools">Fichier</span></trix-toolbar>`)
      const link = Object.assign(document.createElement("link"), { rel: "stylesheet", href, onload: () => done() })
      document.body.append(link)
    JS

    assert_equal "none", css(find("#file-tools", visible: :all), "display")
    assert_equal "24px", css(find("#rich-list"), "padding-left")
    assert_equal "12px", css(find("#rich-list"), "margin-top")
    assert_equal "0px", css(find("#rich-item"), "margin-left")
  end

  test "a toast survives a redirect through the flash, then leaves by itself" do
    find("button[data-redirect]").click

    assert_selector "#toasts [data-toast-type=success]", text: /\d{2}:\d{2}:\d{2}/
    # The toast pauses while hovered (UDR-0006), and the pointer stays where the button was clicked: after the reload,
    # the toast may land under it and never leave. The pointer moves away first; the wait covers the 5 s delay with
    # room for a loaded run.
    find("h1", match: :first).hover
    assert_no_selector "#toasts [data-toast-type=success]", wait: 12
  end

  test "a CRUD form opens in the modal frame, keeps its errors in 422 and closes on success" do
    click_on t("design.index.hotwire.open")
    within("turbo-frame#modal") do
      assert_selector "dialog#design-crud-modal[open]"
      fill_in "sample_name", with: "   " # passe la validation du navigateur, pas celle du serveur
      click_on t("design.modal.submit")

      assert_selector "#sample_name[aria-invalid=true]"
      assert_selector "#sample_name_error", text: t("design.index.sample.errors.name")
      fill_in "sample_name", with: "Awa Koné"
      click_on t("design.modal.submit")
    end

    assert_no_selector "dialog#design-crud-modal", visible: :all
    assert_selector "#toasts [data-toast-type=success]", text: "Awa Koné"
    assert_selector "#design-created", text: "Awa Koné"

    click_on t("design.index.hotwire.open")

    assert_selector "dialog#design-crud-modal[open]"
    find("dialog#design-crud-modal").send_keys(:escape)

    assert_no_selector "turbo-frame#modal *", visible: :all
  end

  test "a lazy frame loads when it scrolls into view, then reloads in place" do
    example = find("[data-example=crud-frame]")

    assert_selector "turbo-frame#design-frame[loading=lazy] [role=status]"
    scroll_to example
    within(example) do
      assert_selector "turbo-frame#design-frame", text: t("design.frame.title")
      click_on t("design.frame.reload")

      assert_selector "turbo-frame#design-frame:not([aria-busy])", text: t("design.frame.title")
    end
  end

  test "empty, error and loading states" do
    assert_selector "[data-example=empty-action] a", text: t("design.index.states.empty_cta")
    assert_selector "[data-example=error-retry] [role=alert] a", text: t("components.error_state.retry")
    assert_selector "[data-example=loading-spinner] [role=status] svg.animate-spin"
    assert_selector "[data-example=loading-skeleton] [role=status][aria-busy=true] .animate-pulse", minimum: 2
  end

  test "pagination disables the missing directions" do
    assert_selector "[data-example=pagination-1] button[disabled]", text: t("components.pagination.previous")
    assert_selector "[data-example=pagination-1] a[rel=next][href$='page=2']"
    assert_selector "[data-example=pagination-3] a[rel=prev]"
    assert_selector "[data-example=pagination-3] a[rel=next]"
    assert_selector "[data-example=pagination-5] button[disabled]", text: t("components.pagination.next")
  end

  test "the shell of every role: sidebar on desktop, bottom bar on mobile" do
    NavigationHelper::DESTINATIONS.each do |role, destinations|
      visit design_shell_path(role)

      assert_selector "aside nav a", count: destinations.size
      assert_no_selector "nav.fixed.bottom-0"
      assert_selector "header", text: t("shared.roles.#{role}")
      assert_selector "main h1", text: t("design.shell.names.#{role}").split.first
      assert_selector "aside a[aria-current=page]", text: t("shared.navigation.home")
    end

    resize_to(390, 844) do
      visit design_shell_path(:team)

      assert_no_selector "aside"
      assert_selector "nav.fixed.bottom-0 a", count: NavigationHelper::DESTINATIONS[:team].size
      find("button[aria-controls=account-menu]").click

      assert_selector "#account-menu [role=menuitem]", text: t("shared.navigation.sign_out")
    end
  end

  test "the landing stays on tokens and speaks French" do
    visit root_path

    assert_selector "h1", text: t("homepage.index.hero.title")
    assert_equal "fr", find("html")["lang"]
    assert_no_selector "link[href*='fonts.googleapis']", visible: :all
    assert_equal "rgb(0, 160, 255)", css(find("#rejoindre > div"), "background-color")
  end

  private

  def t(key, **) = I18n.t(key, **)

  # Valeur calculée par le navigateur, sous sa forme sérialisée CSS (`rgb(…)`), pas celle de WebDriver (`rgba(…)`).
  def css(element, property)
    page.evaluate_script("getComputedStyle(arguments[0]).getPropertyValue(arguments[1])", element, property)
  end

  def active_text
    page.evaluate_script("document.activeElement.textContent").squish
  end

  def send_to_active(key)
    page.driver.browser.action.send_keys(key).perform
  end

  def resize_to(width, height)
    window = page.driver.browser.manage.window
    original = window.size
    window.resize_to(width, height)
    yield
  ensure
    window.resize_to(original.width, original.height)
  end
end
