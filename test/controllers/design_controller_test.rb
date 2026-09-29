require "test_helper"

class DesignControllerTest < ActionDispatch::IntegrationTest
  test "renders every component section of the living style guide" do
    get design_path

    assert_response :success
    %w[colors typography shape icons buttons badges avatars cards fields modal dropdown tabs notifications states pagination shell].each do |section|
      assert_select "section##{section}"
    end
  end

  test "renders the shell of every role" do
    %w[student teacher team school_admin].each do |role|
      get design_shell_path(role:)

      assert_response :success
      assert_select "body > header"
      assert_select "nav", minimum: 2
      assert_select "main#main h1"
    end
  end

  # UDR-0054 §3.9: the search form is a named search landmark (form_with renders them only through `html:`).
  test "the search demonstration is a named search landmark" do
    get design_path

    assert_select "form#design-search-form[role=search][aria-label='#{I18n.t("design.index.finishes.search.label")}']"
  end

  test "refuses an unknown role" do
    assert_raises(ActionController::UrlGenerationError) { design_shell_path(role: "admin") }
  end

  test "appends a toast to the stack by Turbo Stream" do
    post design_toast_path(type: "warning"), as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=toasts] template [data-toast-type=warning]"
  end

  test "falls back to a flash message on a plain HTML post" do
    post design_toast_path(type: "error")

    assert_redirected_to design_path
    assert_predicate flash[:error], :present?
  end

  test "whitelists the toast type" do
    post design_toast_path(type: "__send__"), as: :turbo_stream

    assert_select "[data-toast-type=success]"
  end

  test "serves the landing on design tokens" do
    get root_path

    assert_response :success
    assert_select "h1", I18n.t("homepage.index.hero.title")
    assert_no_match(/fonts\.googleapis/, response.body)
  end

  test "serves the CRUD form inside the modal frame" do
    get design_modal_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal [data-controller=modal][data-modal-open-value=true] form#design-crud-form"
  end

  test "re-renders the form with its errors in 422 when invalid" do
    post design_modal_path, params: { sample: { name: "", email: "awa@exemple.ci" } }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal input#sample_name[aria-invalid=true]"
    assert_select "#sample_name_error", I18n.t("design.index.sample.errors.name")
    assert_select "input#sample_email[value='awa@exemple.ci']"
  end

  test "answers a valid submission with a toast and the new item" do
    post design_modal_path, params: { sample: { name: "Awa Koné" } }, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts] template [data-toast-type=success]"
    assert_select "turbo-stream[action=append][target=design-created] template", text: /Awa Koné/
  end

  test "serves the lazy frame content" do
    get design_frame_path, headers: { "Turbo-Frame" => "design-frame" }

    assert_select "turbo-frame#design-frame", text: /#{I18n.t("design.frame.title")}/
  end

  test "the layout carries the modal frame and the toast stack" do
    get design_path

    assert_select "body > turbo-frame#modal"
    assert_select "body > #toasts[aria-live=polite]"
    assert_select "turbo-frame#design-frame[loading=lazy][src='#{design_frame_path}'] [role=status]"
  end
end
