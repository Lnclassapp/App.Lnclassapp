require "test_helper"

# CA-9 (chantier installation-pwa, UDR-0078 §3.1, amended 2026-10-07): the install invitation is a pop-up on the home page
# of the student and of the teacher only, served closed — the browser alone decides to open it. Their other pages, the
# direction, the team and the public home never carry it.
class Identity::InstallBannerMarkupTest < ActionDispatch::IntegrationTest
  def tb(key) = I18n.t("shared.navigation.install_banner.#{key}")

  test "CA-9 — the student's page carries the banner, hidden, in their words" do
    sign_in_as create_student(classroom: create_classroom)
    get student_home_path

    assert_response :ok
    assert_hidden_banner(role: "student")
  end

  test "CA-9 — the teacher's page carries the banner, hidden, in their words" do
    sign_in_as create_teacher
    get teacher_home_path

    assert_response :ok
    assert_hidden_banner(role: "teacher")
  end

  test "CA-9 — the student's other pages never carry the banner" do
    sign_in_as create_student(classroom: create_classroom)

    [ student_classroom_path, courses_path ].each do |path|
      get path

      assert_response :ok
      assert_no_banner
    end
  end

  test "CA-9 — the direction's page never carries the banner" do
    sign_in_as create_school_admin
    get school_admin_classrooms_path

    assert_response :ok
    assert_no_banner
  end

  test "CA-9 — the team member's page never carries the banner" do
    sign_in_as create_team_member
    get team_home_path

    assert_response :ok
    assert_no_banner
  end

  test "CA-9 — the public home page never carries the banner" do
    get root_path

    assert_response :ok
    assert_no_banner
  end

  private

  def assert_no_banner
    assert_not_includes response.body, "install_banner"
    assert_select "[data-controller~=install]", count: 0
  end

  # Same HTML for every student (or teacher): a closed bottom sheet, the Android button hidden, the iPhone steps hidden.
  def assert_hidden_banner(role:)
    assert_select "main#main div[data-controller=install][data-action='close->install#dismissed:capture']" do
      assert_select "dialog#install_banner.dialog-sheet[aria-labelledby=install_banner-title]:not([open])" do
        assert_select "h2#install_banner-title", text: tb("title.#{role}")
        assert_select "p", text: tb("body.#{role}")
        assert_select "ol[data-install-target=ios][hidden] > li", count: 2
        assert_select "ol li strong", text: "Partager"
        assert_select "button[data-install-target=android][hidden][data-action='install#prompt']", text: tb(:install)
        assert_select "button[data-action='install#later']:not([hidden])", text: tb(:later)
      end
    end
  end
end
