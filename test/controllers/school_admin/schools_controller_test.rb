require "test_helper"

# GD-01, GD-02, GD-03 (ADR-0071, UDR-0056 §3.1, §3.2): « Établissement », the third destination of the direction: the
# teachers' sign-up link to read, copy and share on WhatsApp, then the « Classes par niveau » block shared with the team.
# IE-07 (ADR-0083 §4.1, UDR-0079 §3.7): the link is the direction's /i/<token>, without the code nor « Changer le lien ».
class SchoolAdmin::SchoolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké", school_type: "private", school_code: "k7m4qz")
    @admin = create_school_admin(school: @school)
  end

  def t(key, **) = I18n.t("school_admin.schools.#{key}", **)
  def link = teacher_invite_link_url(@school.reload.direction_invite_token)
  def tn(key) = I18n.t("shared.navigation.#{key}")

  # AN-22 (chantier annonces, UDR-0071 §3.1): « Annonces » closes the direction's navigation, after its three destinations.
  test "GD-01, AN-22: the direction's navigation has four destinations, all drawn, « Établissement » current on its page" do
    sign_in_as @admin
    get school_admin_classrooms_path

    assert_select "aside nav a[href]", 4
    assert_select "aside nav a[aria-disabled]", 0
    assert_select "aside nav a[href='#{school_admin_classrooms_path}']", text: tn(:home)
    assert_select "aside nav a[href='#{school_admin_teachers_path}']", text: tn(:teachers)
    assert_select "aside nav a[href='#{school_admin_school_path}']", text: tn(:school)
    assert_select "aside nav a[href='#{announcements_path}']", text: tn(:announcements)

    get school_admin_school_path

    assert_response :success
    assert_select "aside nav a[aria-current=page][href='#{school_admin_school_path}']", text: tn(:school)
    assert_select "title", text: /\A#{Regexp.escape(t('show.page_title'))}/
  end

  test "GD-03, IE-07: the direction reads its invitation link, copies it and shares it on WhatsApp, without code nor « Changer le lien »" do
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
      assert_match %r{/i/\h{12}\z}, link
      assert_select "#school_code_value", 0
      assert_select "[data-controller=clipboard][data-clipboard-text-value='#{link}'] button[aria-label=?]", t("link.copy_label"),
                    text: t("link.copy")
      assert_select "[data-clipboard-text-value='#{link}'] template[data-clipboard-target=copied]", text: /#{t('link.copied')}/
      message = t("link.share_message", school: "Lycée Moderne de Bouaké", link:)
      assert_select "a#school_link_whatsapp[target=_blank][rel=noopener][href=?]", "https://wa.me/?text=#{ERB::Util.url_encode(message)}",
                    text: t("link.share_whatsapp")
      assert_includes message, link
      assert_includes message, "Lycée Moderne de Bouaké"
    end
    # IE-07: the links are stable (ADR-0083 §4.1): no « Changer le lien », no form, and the code is never shown.
    assert_select "#school_link form, #school_link dialog, #change-school-link", 0
    assert_select "#school_link", text: /Changer le lien/, count: 0
    assert_no_match(/k7m4qz|K7M-?4QZ/i, response.body)
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
    assert_select "a#school_link_value[href='#{link}']"
    assert_select "#school_level_classrooms_inactive"
  end

  test "GD-12: an inactive school offers the direction neither « + » nor « − », even on a last unused classroom" do
    referential = seed_referential
    create_classroom(school: @school, level: referential[:levels]["6eme"], name: "6ème 1")
    @school.update!(status: "inactive")
    sign_in_as @admin

    get school_admin_school_path

    assert_select "#level_classrooms_6eme"
    assert_select "#level_classrooms_6eme form", 0
    assert_select "#level_classrooms_6eme dialog", 0
    assert_select "#level_classrooms_6eme button", 0
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

  # ID-11, ID-13, ID-16 (ADR-0077, UDR-0070 §3.4): the « Direction » block, after #school_link.
  def ts(key, **) = I18n.t("shared.school_staff.#{key}", **)

  def seed_staff
    @kofi = create_school_admin(school: @school, first_name: "Kofi", last_name: "Yao", joined_via: "code", joined_at: 10.days.ago)
    @aya = create_school_admin(school: @school, first_name: "Aya", last_name: "Koné", joined_via: "code", joined_at: 2.days.ago)
    create_school_admin(school: @school, first_name: "Gone", last_name: "Archivé", joined_via: "code", archived_at: 1.day.ago)
    create_school_admin(school: create_school, first_name: "Zadi", last_name: "Ailleurs", joined_via: "code")
  end

  test "ID-11: Kofi reads the « Direction » block after the link, « (vous) » on his line, the ⋮ menu on the others only" do
    seed_staff
    sign_in_as @kofi
    get school_admin_school_path

    assert_response :success
    assert_select "#school_link + #school_staff"
    assert_select "#school_staff" do
      assert_select "#school_staff_places", text: ts("subtitle", used: 2, cap: 3)
      assert_select "#school_staff_list li", 3
      assert_select "li#school_staff_#{@kofi.public_id}", text: /Kofi Yao\s+#{Regexp.escape(ts('you'))}/
      assert_select "li#school_staff_#{@kofi.public_id} [aria-haspopup]", 0
      assert_select "li#school_staff_#{@admin.public_id} [aria-label=?]", ts("actions", name: "#{@admin.first_name} #{@admin.last_name}")
      assert_select "li#school_staff_#{@aya.public_id} [aria-label=?]", ts("actions", name: "Aya Koné")
      assert_select "dialog#remove-staff-#{@aya.public_id} h2", text: ts("confirm.title", name: "Aya Koné")
      assert_select "form#remove-staff-#{@aya.public_id}-form[action='#{school_admin_staff_member_path(@aya.public_id)}'] " \
                    "input[name=_method][value=delete]"
      assert_select "#school_staff_newcomer", 0
    end
    [ "Archivé", "Ailleurs" ].each { assert_not_includes response.body, it }
  end

  test "ID-13: Aya (2 days) has no ⋮ menu on any line, and the newcomer note" do
    seed_staff
    sign_in_as @aya
    get school_admin_school_path

    assert_select "#school_staff_list li", 3
    assert_select "#school_staff [aria-haspopup]", 0
    assert_select "#school_staff form", 0
    assert_select "#school_staff_newcomer.text-xs.text-mute", text: ts("newcomer")
  end

  test "ID-16: an inactive school shows the block without any ⋮ menu" do
    seed_staff
    @school.update!(status: "inactive")
    sign_in_as @kofi
    get school_admin_school_path

    assert_response :success
    assert_select "#school_staff_list li", 3
    assert_select "#school_staff [aria-haspopup]", 0
    assert_select "#school_staff_newcomer", 0
  end
end
