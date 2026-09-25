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
end
