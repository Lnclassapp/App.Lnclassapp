require "test_helper"

# GD-01, GD-02, GD-03 (ADR-0071, UDR-0056 §3.1, §3.2): « Établissement », the third destination of the direction: the
# teachers' sign-up link to read, copy and share on WhatsApp, then the « Classes par niveau » block shared with the team.
class SchoolAdmin::SchoolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké", school_type: "private", school_code: "k7m4qz")
    @admin = create_school_admin(school: @school)
  end

  def t(key, **) = I18n.t("school_admin.schools.#{key}", **)
  def tn(key) = I18n.t("shared.navigation.#{key}")

  test "GD-01: the direction's navigation has three destinations, all drawn, « Établissement » current on its page" do
    sign_in_as @admin
    get school_admin_classrooms_path

    assert_select "aside nav a[href]", 3
    assert_select "aside nav a[aria-disabled]", 0
    assert_select "aside nav a[href='#{school_admin_classrooms_path}']", text: tn(:student_work)
    assert_select "aside nav a[href='#{school_admin_teachers_path}']", text: tn(:teachers)
    assert_select "aside nav a[href='#{school_admin_school_path}']", text: tn(:school)

    get school_admin_school_path

    assert_response :success
    assert_select "aside nav a[aria-current=page][href='#{school_admin_school_path}']", text: tn(:school)
    assert_select "title", text: /\A#{Regexp.escape(t('show.page_title'))}/
  end

  test "GD-03: the direction reads its link and code, copies the link and shares it on WhatsApp with the school's name" do
    link = school_code_signup_url("k7m4qz")
    sign_in_as @admin

    get school_admin_school_path

    assert_response :success
    assert_select "h1", text: "Lycée Moderne de Bouaké"
    assert_select "main", text: /#{I18n.t('school_types.private')}/
    assert_select "#school_inactive_notice", 0
    assert_select "#school_link", text: /#{Regexp.escape(t('show.link_title'))}/
    assert_select "#school_link", text: /#{Regexp.escape(t('show.link_subtitle'))}/
    assert_select "#school_link #school_link_block" do
      assert_select "#school_link_label", text: t("link.label")
      assert_select "a#school_link_value[href='#{link}'][aria-labelledby=school_link_label]", text: link
      assert_match %r{/e/k7m4qz\z}, link
      assert_select "#school_code_value", text: "K7M-4QZ"
      assert_select "[data-controller=clipboard][data-clipboard-text-value='#{link}'] button[aria-label=?]", t("link.copy_label"),
                    text: t("link.copy")
      assert_select "[data-clipboard-text-value='#{link}'] template[data-clipboard-target=copied]", text: /#{t('link.copied')}/
      message = t("link.share_message", school: "Lycée Moderne de Bouaké", link:)
      assert_select "a#school_link_whatsapp[target=_blank][rel=noopener][href=?]", "https://wa.me/?text=#{ERB::Util.url_encode(message)}",
                    text: t("link.share_whatsapp")
      assert_includes message, link
      assert_includes message, "Lycée Moderne de Bouaké"
    end
    # The only form of the card is « Changer le lien » (Lot A), behind its confirmation.
    assert_select "#school_link form", 1
    assert_select "#school_link dialog#change-school-link form#change-school-link-form", 1
  end

  test "the « Classes par niveau » block is the team's, its « + » and « − » aimed at the direction's routes" do
    referential = seed_referential
    sixths = (1..2).map { create_classroom(school: @school, level: referential[:levels]["6eme"], name: "6ème #{it}") }
    sign_in_as @admin

    get school_admin_school_path

    assert_select "#school_level_classrooms h3#school_level_classrooms_title", text: I18n.t("teams.level_classrooms.block.title")
    assert_select "#level_classrooms_6eme [role=group][aria-label=?]", I18n.t("teams.level_classrooms.block.count", level: "6ème", count: 2)
    assert_select "#level_classrooms_6eme dialog form[action='#{school_admin_level_classroom_path(sixths.last.public_id)}'] " \
                  "input[name=_method][value=delete]", 1
    assert_select "#level_classrooms_6eme form[action='#{school_admin_level_classrooms_path}'] input[name=level][value='6eme']"
    assert_select "form[action*='/teams/']", 0
    assert_not_includes response.body, @school.public_id
  end

  test "an inactive school: the link is read, a notice says why nothing can change, the block offers no « + »" do
    @school.update!(status: "inactive")
    sign_in_as @admin

    get school_admin_school_path

    assert_response :success
    assert_select "#school_inactive_notice.text-warning", text: t("show.inactive")
    assert_select "a#school_link_value[href='#{school_code_signup_url('k7m4qz')}']"
    assert_select "#school_level_classrooms_inactive"
  end

  test "the page reads the direction's own school, never another" do
    other = create_school(name: "Lycée Classique d'Abidjan", school_code: "abc234")
    sign_in_as create_school_admin(school: other)

    get school_admin_school_path

    assert_select "h1", text: "Lycée Classique d'Abidjan"
    assert_not_includes response.body, "k7m4qz"
    assert_not_includes response.body, "Bouaké"
  end

  test "GD-02: a student, a teacher, a team member and a detached direction receive 403; a visitor signs in" do
    get school_admin_school_path
    assert_redirected_to new_session_path

    [ create_student, create_teacher(school: @school), create_team_member, create_user(role: "school_admin") ].each do |user|
      sign_in_as user
      get school_admin_school_path
      assert_response :forbidden, user.role
      sign_out
    end
  end
end
