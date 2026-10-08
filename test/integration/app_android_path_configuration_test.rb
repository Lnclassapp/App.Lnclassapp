require "test_helper"

# Chantier app-android, Lot B — CA-2 (ADR-0084 §4.3, UDR-0080 §3.3). The site serves the path configuration of the Android
# shell, a static, versioned file: every address in the current tab, the exercise session in a full-screen modal (its
# result back in the tab), the account panel and the help in a modal.
class AppAndroidPathConfigurationTest < ActionDispatch::IntegrationTest
  PATH = "/android/v1/path-configuration.json".freeze

  def configuration = JSON.parse(Rails.public_path.join(PATH.delete_prefix("/")).read)

  # Hotwire Native merges the properties of every rule whose pattern matches the path, the later ones winning.
  def properties(path)
    configuration["rules"].select { |rule| rule["patterns"].any? { Regexp.new(it).match?(path) } }
                          .reduce({}) { |merged, rule| merged.merge(rule["properties"]) }
  end

  test "CA-2 — the site serves the file as JSON" do
    get PATH

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal configuration, response.parsed_body
  end

  test "CA-2 — every address opens in the current tab, as a web page that can be pulled to refresh" do
    assert_equal({}, configuration["settings"])
    assert_equal({ "context" => "default", "uri" => "hotwire://fragment/web", "pull_to_refresh_enabled" => true },
                 properties("/students"))
  end

  test "CA-2 — the exercise session opens in a modal, its result comes back in the tab" do
    session = Rails.application.routes.url_helpers.exercise_session_path("abc123")
    result = Rails.application.routes.url_helpers.exercise_session_result_path("abc123")

    assert_equal "/sessions/abc123", session
    assert_equal({ "context" => "modal", "uri" => "hotwire://fragment/web", "pull_to_refresh_enabled" => false },
                 properties(session))
    assert_equal "default", properties(result)["context"]
    assert_equal "default", properties("/exercises/abc123")["context"]
  end

  test "CA-2 — the account panel and the help open in a modal" do
    helpers = Rails.application.routes.url_helpers

    [ helpers.student_menu_path, helpers.help_path ].each do |path|
      assert_equal "modal", properties(path)["context"], path
      assert_equal false, properties(path)["pull_to_refresh_enabled"], path
    end
    assert_equal [ "/students/menu", "/aide" ], [ helpers.student_menu_path, helpers.help_path ]
    assert_equal "default", properties("/students/classroom")["context"]
  end

  # Lnclass Teacher, Lot TB — CA-T2 (ADR-0086 §4.3): one file for both apps; the teacher's account panel, the new
  # assignment and the session days open in a modal, the rest of the teacher's space in the tab.
  test "CA-T2 — the teacher's account panel, a new assignment and the session days open in a modal" do
    helpers = Rails.application.routes.url_helpers
    paths = [ helpers.teacher_menu_path, helpers.new_classroom_assignment_path("cls123"),
              helpers.edit_classroom_session_days_path("cls123") ]

    assert_equal [ "/teachers/menu", "/classrooms/cls123/assignments/new", "/classrooms/cls123/session_days/edit" ], paths
    paths.each do |path|
      assert_equal({ "context" => "modal", "uri" => "hotwire://fragment/web", "pull_to_refresh_enabled" => false },
                   properties(path), path)
    end
    [ helpers.teacher_home_path, helpers.teacher_classrooms_path, helpers.classroom_assignment_path("cls123", "asg456"),
      "/classrooms/cls123/assignments/new/extra" ].each do |path|
      assert_equal "default", properties(path)["context"], path
    end
  end
end
