require "test_helper"

# ADR-0051 : the browser floor never blocks; it only flags the request for the layout banner.
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  OLD_ANDROID = "Mozilla/5.0 (Linux; Android 6.0; TECNO W3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.5249.126 Mobile Safari/537.36"
  FLOOR       = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Mobile Safari/537.36"

  test "a browser below the floor is served and flagged as outdated" do
    get root_path, headers: { "User-Agent" => OLD_ANDROID }

    assert_response :ok
    assert controller.instance_variable_get(:@outdated_browser)
  end

  test "a browser at the floor is served without the flag" do
    get root_path, headers: { "User-Agent" => FLOOR }

    assert_response :ok
    assert_nil controller.instance_variable_get(:@outdated_browser)
  end

  test "the floor is Tailwind v4's, and Internet Explorer is only flagged" do
    assert_equal({ chrome: 111, safari: 16.4, firefox: 128, ie: false }, ApplicationController::SUPPORTED_BROWSERS)
  end

  # ADR-0084 §4.1 : la coque élèves se reconnaît à « Hotwire Native » et à son jeton ; le jeton seul, ou la bibliothèque
  # seule, ne suffit pas.
  APP = "Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 " \
        "Hotwire Native Android; LnclassStudentAndroid/1.0".freeze

  test "each shell is recognised by Hotwire Native and its own token, and nothing else is" do
    {
      APP => :android_student,
      APP.sub("LnclassStudentAndroid", "LnclassTeacherAndroid") => :android_teacher, # ADR-0086 §4.1
      "#{FLOOR} LnclassTeacherAndroid/1.0" => nil,
      "#{FLOOR} Hotwire Native Android" => nil,
      "#{FLOOR} LnclassStudentAndroid/1.0" => nil,
      FLOOR => nil
    }.each do |agent, expected|
      get root_path, headers: { "User-Agent" => agent }

      assert_equal [ expected, !expected.nil? ], [ controller.send(:lnclass_app), controller.send(:lnclass_app?) ], agent
    end
  end
end
