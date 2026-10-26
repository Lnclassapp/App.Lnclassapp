require "test_helper"

# CA-T6 (app-android, Lnclass Teacher) — UDR-0082 §3.2. « /teachers/menu » renders the teacher's account panel as a
# page: the content of the header's <dialog>, which the teachers' shell opens as a modal and the site reaches without
# JavaScript. Teacher only.
class Classroom::TeacherMenusControllerTest < ActionDispatch::IntegrationTest
  def tn(key, **) = I18n.t("shared.navigation.#{key}", **)

  def maths = create_material(name: "Mathématiques", shortname: "Maths")
  def pc = create_material(name: "Physique-Chimie", shortname: "PC")
  def svt = create_material(name: "SVT", shortname: "SVT")

  # Ce que le panneau montre, dans l'ordre : en-tête, entrées (liens), interrupteur, déconnexion.
  def assert_entries(scope, hrefs:, texts:)
    links = css_select("#{scope} nav[aria-label='#{tn('account_panel.label')}'] a.min-h-14")
    assert_equal hrefs, links.map { it["href"] }
    assert_equal texts, links.map { it.text.squish }
    assert_select "#{scope} a[href='#{teacher_invite_path}']", 0
    assert_select "#{scope} [data-controller=theme] button[role=switch]", text: tn("account_panel.entries.dark_mode")
    assert_select "#{scope} form[action='#{session_path}'] button[type=submit]", tn(:sign_out)
  end

  test "CA-T6, CA-H1: the teacher reads « Mon compte » as a page — name, « Maths · PC · sigle », four entries with « N sur 3 », theme, sign out; no « Invite a colleague »" do
    school = create_school(name: "Lycée moderne 2", sigle: "LM2")
    sign_in_as create_teacher(school:, materials: [ maths, pc ], first_name: "Awa", last_name: "Traoré")

    get teacher_menu_path

    assert_response :success
    assert_select "title", text: /\A#{tn('account_panel.title')}/
    assert_select "h1", tn("account_panel.title")
    assert_select "main #teacher_menu" do
      assert_select "[role=img][aria-label='Awa Traoré']", text: "AT"
      assert_select "p", "Awa Traoré"
      assert_select "p", "Maths · PC · LM2"
      assert_select "#account_schools", 0
    end
    assert_entries "main #teacher_menu",
                   hrefs: [ profile_path, edit_profile_pin_path, edit_profile_materials_path, teacher_schools_path ],
                   texts: [ tn(:profile), tn("account_panel.entries.secret"),
                            "#{tn('account_panel.entries.add_material')} #{tn('account_panel.counter.under', used: 2, max: 3)}",
                            "#{tn('account_panel.entries.add_school')} #{tn('account_panel.counter.under', used: 1, max: 3)}" ]
    assert_select "main dialog#account_panel", 0
  end

  # CA-H7 (lot P0) : le menu est le contenu d'un frame. Sur la page, rien ne change ; ramené dans le frame du panneau par
  # « ‹ Mon compte », il en sort par ses liens et ses envois, sauf l'écran de retrait, qui reste dans le frame dès lg (à 3 sur 3).
  test "CA-H7: the page has no frame; returned in the frame of the panel, the menu leaves it, except the removal screens from lg" do
    school = create_school(name: "Lycée moderne 2", sigle: "LM2")
    sign_in_as create_teacher(school:, materials: [ maths, pc, svt ])

    get teacher_menu_path
    assert_select "main turbo-frame", 0
    assert_select "main [data-turbo-frame]", 0
    assert_select "main nav a[href='#{profile_materials_path}']", 1

    get teacher_menu_path, headers: { "Turbo-Frame" => NavigationHelper::ACCOUNT_PANEL_FRAME }

    assert_response :success
    assert_no_match(/<aside|<header|<main/, response.body)
    assert_select "turbo-frame##{NavigationHelper::ACCOUNT_PANEL_FRAME}", 1 do
      assert_select "a[href='#{profile_path}'][data-turbo-frame=_top]"
      assert_select "form[action='#{session_path}'][data-turbo-frame=_top]"
      assert_select "li.lg\\:hidden a[href='#{profile_materials_path}'][data-turbo-frame=_top]", 1
      assert_select "li.max-lg\\:hidden a[href='#{profile_materials_path}'][data-turbo-frame='#{NavigationHelper::ACCOUNT_PANEL_FRAME}']", 1
    end
  end

  test "CA-H1: one subject reads its short name, and a school without a sigle reads its name" do
    sign_in_as create_teacher(school: create_school(name: "Lycée moderne 2", sigle: nil), materials: [ maths ])

    get teacher_menu_path

    assert_select "main #teacher_menu p", "Maths · Lycée moderne 2"
  end

  test "CA-H2: from two schools, « Établissement en cours » lists them, the current one checked and disabled, the other switchable" do
    csmt = create_school(name: "Collège Saint-Michel de Treichville", sigle: "CSMT")
    lmt = create_school(name: "Lycée Moderne de Treichville", sigle: "LMT")
    teacher = create_teacher(school: csmt, materials: [ maths ])
    add_teacher_school(teacher, lmt)
    sign_in_as teacher

    get teacher_menu_path

    assert_select "main p", "Maths · CSMT"
    assert_select "main #account_schools h2", tn("account_panel.schools.current_heading")
    assert_select "main #account_schools li", 2
    assert_select "main #account_schools button[aria-current=true][disabled]", count: 1, text: /CSMT.*Collège Saint-Michel de Treichville/m
    assert_select "main #account_schools form[action='#{teacher_current_school_path}'] input[name=school_public_id][value='#{lmt.public_id}']"
    assert_select "main #account_schools button[aria-label='#{tn('account_panel.schools.switch', school: lmt.name)}']:not([disabled])", text: /LMT/
    assert_select "main #account_schools", text: /Principal/, count: 0
    assert_select "main nav a", text: /#{tn('account_panel.entries.add_school')}\s+#{tn('account_panel.counter.under', used: 2, max: 3)}/
  end

  test "CA-H1: at 3 on 3, the entries turn grey, say how to add one, and lead to the removal screens" do
    schools = %w[CSMT LMT LCK].map { create_school(name: "Établissement #{it}", sigle: it) }
    teacher = create_teacher(school: schools.first, materials: [ maths, pc, svt ])
    schools.drop(1).each { add_teacher_school(teacher, it) }
    sign_in_as teacher

    get teacher_menu_path

    assert_select "main p", "Maths · PC · SVT · CSMT"
    assert_entries "main #teacher_menu",
                   hrefs: [ profile_path, edit_profile_pin_path, profile_materials_path, teacher_schools_path ],
                   texts: [ tn(:profile), tn("account_panel.entries.secret"),
                            "#{tn('account_panel.entries.add_material')} #{tn('account_panel.counter.full.materials', used: 3, max: 3)}",
                            "#{tn('account_panel.entries.add_school')} #{tn('account_panel.counter.full.schools', used: 3, max: 3)}" ]
    assert_equal "3 sur 3 · retirez-en une pour en ajouter", tn("account_panel.counter.full.materials", used: 3, max: 3)
    assert_equal "3 sur 3 · retirez-en un pour en ajouter", tn("account_panel.counter.full.schools", used: 3, max: 3)
    assert_select "main nav a[href='#{profile_materials_path}'] > span.bg-mist.text-mute", 1
    assert_select "main nav a[href='#{teacher_schools_path}'] > span.bg-mist.text-mute", 1
    assert_select "main nav a[href='#{profile_path}'] > span.bg-brand-soft", 1
    assert_select "main #account_schools li", 3
  end

  test "CA-H1: on another page, the header avatar opens the same panel in a full-screen <dialog>" do
    sign_in_as create_teacher(school: create_school(name: "Lycée moderne 2", sigle: "LM2"), materials: [ maths ],
                              first_name: "Awa", last_name: "Traoré")

    get teacher_classrooms_path

    assert_response :success
    assert_select "header a[href='#{teacher_menu_path}'][data-action='modal#open'][aria-haspopup=dialog][aria-controls=account_panel]" do
      assert_select "span.sr-only", tn("account_panel.open")
    end
    assert_select "header dialog#account_panel[aria-labelledby=account_panel_title].h-dvh.w-full" do
      assert_select "h2#account_panel_title", tn("account_panel.title")
      assert_select "button[aria-label='#{I18n.t('components.modal.close')}']", 1
      assert_select "p", "Maths · LM2"
    end
    assert_entries "header dialog#account_panel",
                   hrefs: [ profile_path, edit_profile_pin_path, edit_profile_materials_path, teacher_schools_path ],
                   texts: [ tn(:profile), tn("account_panel.entries.secret"),
                            "#{tn('account_panel.entries.add_material')} #{tn('account_panel.counter.under', used: 1, max: 3)}",
                            "#{tn('account_panel.entries.add_school')} #{tn('account_panel.counter.under', used: 1, max: 3)}" ]
  end

  test "CA-T6: a student and the team are refused" do
    [ create_student, create_team_member ].each do |user|
      sign_in_as user

      get teacher_menu_path

      assert_response :forbidden
      sign_out
    end
  end

  test "without a session, the page sends to the sign-in" do
    get teacher_menu_path

    assert_redirected_to new_session_path
  end
end
