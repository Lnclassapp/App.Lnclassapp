require "test_helper"

# Porteur, 2026-10-08 : les pages publiques vues dans « Lnclass Teacher » montrent le logo des enseignants ; dans un
# navigateur, le logo bleu, sauf sur l'inscription enseignant.
class AppAndroidBrandLogoTest < ActionDispatch::IntegrationTest
  TEACHER_APP = "Mozilla/5.0 (Linux; Android 13; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 " \
                "Hotwire Native Android; LnclassTeacherAndroid/1.0".freeze

  def logos = css_select("img[src*='logo/lnclass']").map { File.basename(it["src"])[/\Alnclass(-teacher)?/] }.uniq

  test "the sign-in page shows the teachers' logo in the teachers' app and the blue one in a browser" do
    get new_session_path, headers: { "User-Agent" => TEACHER_APP }

    assert_equal [ "lnclass-teacher" ], logos

    get new_session_path

    assert_equal [ "lnclass" ], logos
  end

  test "the teacher sign-up shows the teachers' logo, even in a browser" do
    get new_teacher_registration_path

    assert_equal [ "lnclass-teacher" ], logos
  end
end
