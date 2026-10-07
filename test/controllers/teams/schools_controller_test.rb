require "test_helper"

# ADR-0030, ADR-0036, UDR-0006, UDR-0036 (SC-03 to SC-07): the national list of schools, a school's page, its edition in
# the modal frame, its deactivation, its deletion refused while it is used. No screen and no route creates a school:
# schools only come in through the JSON import.
class Teams::SchoolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @drena = create_drena(name: "Abidjan 1")
  end

  def school_params(**overrides)
    { school: { drena_public_id: @drena.public_id, name: "Lycée Classique d'Abidjan", sigle: "LCA", school_type: "public",
                status: "active", cycle: "both" }.merge(overrides) }
  end

  def error_message(attribute, kind)
    I18n.t("activemodel.errors.models.dtos/school/school_input.attributes.#{attribute}.#{kind}")
  end

  test "outside the team, every action is refused" do
    school = create_school(drena: @drena)
    sign_in_as create_teacher(school:)

    get schools_path
    assert_response :forbidden
    get school_path(school.public_id)
    assert_response :forbidden
    get edit_school_path(school.public_id)
    assert_response :forbidden
    get deactivation_school_path(school.public_id)
    assert_response :forbidden
    get deletion_school_path(school.public_id), headers: { "Turbo-Frame" => "modal" }
    assert_response :forbidden
    patch school_path(school.public_id), params: school_params
    assert_response :forbidden
    patch deactivate_school_path(school.public_id), as: :turbo_stream
    assert_response :forbidden
    delete school_path(school.public_id), as: :turbo_stream
    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t('errors.codes.forbidden')}/
    assert_equal "active", school.reload.status
  end

  test "SC-03: no route creates a school — /teams/schools/new is not a school's page, and POST creates nothing" do
    create_school(drena: @drena)
    sign_in_as @member

    assert_not respond_to?(:new_school_path)
    assert_no_difference -> { Orm::School.count } do
      get "/teams/schools/new"
      assert_response :not_found
      assert_select "main", text: /#{I18n.t('errors.not_found.title')}/

      get "/teams/schools/new", headers: { "Turbo-Frame" => "modal" }
      assert_response :not_found

      post "/teams/schools", params: school_params
      assert_response :not_found
    end
  end

  test "SC-03, SC-04: the list is the national one; its main action imports schools, and nothing creates one" do
    school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan", sigle: "LCA", school_type: "mixed", cycle: "first")
    create_classroom(school:)
    create_teacher(school:)
    create_school(drena: create_drena(name: "Bouaké"), name: "Collège Moderne")
    sign_in_as @member

    get schools_path

    assert_response :success
    assert_select "h1", text: I18n.t("teams.schools.index.title")
    assert_select "a[data-turbo-frame=modal][href='#{new_teams_import_path(kind: 'schools')}']",
                  text: I18n.t("teams.schools.index.import")
    assert_select "a[href$='/schools/new'], form[action='#{schools_path}'][method=post]", 0
    assert_select "turbo-frame#schools[data-turbo-action=advance]"
    assert_select "#schools_total", text: I18n.t("teams.schools.index.total", count: 2)
    assert_select "#schools_list tr", 2
    assert_select "#schools_list tr:first-child", text: /Collège Moderne/
    assert_select "#school_#{school.public_id} a[data-turbo-frame=_top][href='#{school_path(school.public_id)}']",
                  text: "Lycée Classique d'Abidjan"
    assert_select "#school_#{school.public_id}", text: /LCA/
    # Demande du porteur (2026-10-01) : le code d'établissement est dans le tableau, groupé comme sur la fiche, avec son aide.
    assert_select "thead th", text: /#{I18n.t('teams.schools.index.columns.school_code')}/
    assert_select "thead details summary .sr-only", text: I18n.t("components.info_tip.label",
                                                                 label: I18n.t("teams.schools.index.columns.school_code"))
    assert_select "#school_#{school.public_id} td.font-mono",
                  text: Entities::School::SchoolCode.display(Orm::School.find(school.id).school_code)
    assert_select "#school_#{school.public_id}", text: /Abidjan 1/
    assert_select "#school_#{school.public_id}", text: /#{I18n.t('school_types.mixed')}/
    assert_select "#school_#{school.public_id}", text: /#{I18n.t('teams.schools.cycles.first')}/
    assert_select "#school_#{school.public_id}", text: /#{I18n.t('school_statuses.active')}/
    assert_select "#school_#{school.public_id} td.tabular-nums", text: "1", count: 2
    assert_select "#school_#{school.public_id} a[data-turbo-frame=modal][href='#{edit_school_path(school.public_id)}']"
    # Lot E3 (politique-cache) : la ligne ne porte plus ses confirmations, seulement leurs liens vers le frame « modal ».
    assert_select "#school_#{school.public_id} a[data-turbo-frame=modal][href='#{deactivation_school_path(school.public_id)}']",
                  text: I18n.t("teams.schools.school_row.deactivate")
    assert_select "#school_#{school.public_id} a[data-turbo-frame=modal][href='#{deletion_school_path(school.public_id)}']",
                  text: I18n.t("teams.schools.school_row.delete")
    assert_select "#schools_list dialog, #schools_list form", 0
    assert_select "#schools_empty", 0
    assert_select "nav[aria-label='#{I18n.t('components.pagination.label')}']", 0
  end

  test "an empty list invites to import the first file" do
    sign_in_as @member

    get schools_path

    assert_select "#schools_list tr", 0
    assert_select "#schools_empty", text: /#{I18n.t('teams.schools.index.empty_title')}/
    assert_select "#schools_empty a[data-turbo-frame=modal][href='#{new_teams_import_path(kind: 'schools')}']"
  end

  test "filtering with no result says so, and offers to clear the filters" do
    create_school(drena: @drena, name: "Lycée Moderne")
    sign_in_as @member

    get schools_path(search: "introuvable")

    assert_select "#schools_list tr", 0
    assert_select "#schools_empty", text: /#{I18n.t('teams.schools.index.no_match_title')}/
    assert_select "#schools_empty a[href='#{schools_path}'][data-turbo-frame=_top]"
  end

  test "SC-04: the filters keep their values; from the frame, only the frame comes back, paginated" do
    other = create_drena(name: "Bouaké")
    51.times { |index| create_school(drena: @drena, name: format("Lycée %02d", index), school_type: "private") }
    create_school(drena: other, name: "Lycée public", school_type: "public")
    sign_in_as @member

    get schools_path(drena: @drena.public_id, school_type: "private", cycle: "both", status: "active", search: "lycée")

    assert_select "form[action='#{schools_path}'][method=get][data-turbo-frame=schools][data-turbo-action=advance]"
    assert_select "select[name=drena] option[selected][value='#{@drena.public_id}']"
    assert_select "select[name=school_type] option[selected][value=private]"
    assert_select "select[name=cycle] option[selected][value=both]"
    assert_select "select[name=status] option[selected][value=active]"
    assert_select "input[name=search][value='lycée']"
    assert_select "#schools_total", text: I18n.t("teams.schools.index.total", count: 51)
    assert_select "#schools_list tr", 50

    get schools_path(drena: @drena.public_id, school_type: "private", page: 2), headers: { "Turbo-Frame" => "schools" }

    assert_response :success
    assert_select "h1", 0
    assert_select "form[action='#{schools_path}'][method=get]", 0
    assert_select "turbo-frame#schools #schools_list tr", 1
    assert_select "turbo-frame#schools #schools_list tr", text: /Lycée 50/
    assert_select "turbo-frame#schools nav a[rel=prev][href*='page=1'][href*='school_type=private']"
  end

  test "SC-05: a school's page shows its header, its classrooms of the year by level, and its teachers" do
    school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan", sigle: "LCA", school_type: "public", cycle: "both")
    sixth = create_level(name: "6ème", position: 1, cycle: "first")
    final = create_level(name: "Tle", position: 7)
    tle = create_classroom(school:, level: final, series: create_series(name: "D"), name: "Tle D 1", join_code: "kfm37")
    create_classroom(school:, level: sixth, name: "6ème 1")
    create_student(classroom: tle)
    create_teacher(school:, first_name: "Awa", last_name: "Koné", classrooms: [ tle ],
                   material: create_material(name: "SVT", category: "science"))
    sign_in_as @member

    get school_path(school.public_id)

    assert_response :success
    assert_select "#school_header h1", text: "Lycée Classique d'Abidjan"
    assert_select "#school_header", text: /LCA/
    assert_select "#school_header", text: /Abidjan 1/
    assert_select "#school_header", text: /#{I18n.t('school_types.public')}/
    assert_select "#school_header", text: /#{I18n.t('teams.schools.cycles.both')}/
    assert_select "#school_header", text: /#{I18n.t('school_statuses.active')}/
    assert_select "a[data-turbo-frame=modal][href='#{new_school_classroom_path(school.public_id)}']",
                  text: I18n.t("teams.schools.header.add_classroom")
    assert_select "#school_header a[data-turbo-frame=modal][href='#{edit_school_path(school.public_id)}']"
    assert_select "#school_header form[action='#{deactivate_school_path(school.public_id)}']"
    assert_select "section[aria-labelledby^=level_] h3", 2
    assert_select "section h3", text: "6ème"
    assert_select "#classroom_#{tle.public_id}", text: /Tle D 1/
    assert_select "#classroom_#{tle.public_id}", text: /KFM37/
    assert_select "#classroom_#{tle.public_id}", text: /Awa Koné/
    assert_select "#classroom_#{tle.public_id} a[data-turbo-frame=_top][href='#{classroom_path(tle.public_id)}']"
    assert_select "#school_teachers li", text: /Awa Koné/
    assert_select "#school_teachers li", text: /SVT/
    assert_select "nav a[aria-current=page]", text: I18n.t("shared.navigation.schools")
  end

  test "CE-06, IE-08: a school's page shows the direction's code, the team's invitation link, and « Régénérer le code » in the menu" do
    school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    sign_in_as @member

    get school_path(school.public_id)

    header = "teams.schools.header"
    link = teacher_invite_link_url(school.reload.team_invite_token)
    assert_match %r{/i/\h{12}\z}, link
    assert_select "#school_code #school_code_label", text: I18n.t("#{header}.school_code")
    assert_select "#school_code #school_code_value[aria-labelledby=school_code_label]", text: "K7M-4QZ"
    # FU-26 : les deux copies passent par le contrôleur unique `clipboard` (UDR-0054 §3.5), boutons cachés sans JavaScript.
    assert_select "[data-controller~='classroom--join-code-copy']", 0
    assert_select "#school_code [data-controller=clipboard][data-clipboard-text-value='K7M-4QZ'] " \
                  "button[hidden][data-action='clipboard#copy'][aria-label='#{I18n.t("#{header}.copy_code_label", code: 'K7M-4QZ')}']",
                  text: I18n.t("#{header}.copy_code")
    assert_select "#school_code [data-controller=clipboard][data-clipboard-text-value='#{link}'] " \
                  "button[hidden][data-action='clipboard#copy'][aria-label=\"#{I18n.t("#{header}.copy_link_label")}\"]",
                  text: I18n.t("#{header}.copy_link")
    assert_select "#school_code [data-clipboard-text-value='K7M-4QZ'] template[data-clipboard-target=copied]",
                  text: /#{Regexp.escape(I18n.t('shared.clipboard.copied_code'))}/
    assert_select "#school_code [data-clipboard-text-value='#{link}'] template[data-clipboard-target=copied]",
                  text: /#{Regexp.escape(I18n.t('shared.clipboard.copied_link'))}/
    assert_select "#school_code a#school_code_link[href='#{link}'][aria-labelledby=school_invite_link_label]", text: link
    assert_select "#school_code #school_invite_link_label", text: "Lien d'invitation des enseignants"
    assert_select "#school_code", text: /Pour l'inscription de la direction\./
    assert_equal "Pour l'inscription de la direction.", I18n.t("#{header}.school_code_hint")
    assert_select "#school_code a[href*='/e/']", 0
    assert_select "#school_code", { text: /#{Regexp.escape(I18n.t("#{header}.school_code_inactive"))}/, count: 0 }
    assert_select "#school-header-actions button[aria-controls=regenerate-school-code]", text: I18n.t("#{header}.regenerate_code")
    assert_select "dialog#regenerate-school-code form#regenerate-school-code-form[action='#{school_code_path(school.public_id)}'] " \
                  "input[name=_method][value=patch]"
    assert_select "dialog#regenerate-school-code", text: /K7M-4QZ/
  end

  test "IE-15: each teacher of the list reads « Inscription : » and their arrival channel, the colleague named when known" do
    school = create_school(drena: @drena)
    awa = create_teacher(school:, first_name: "Awa", last_name: "Koné", joined_via: "standard")
    create_referral(referrer: awa, referee: create_teacher(school:, first_name: "Yao", last_name: "Brou", joined_via: "colleague"))
    gone = create_teacher(school:, first_name: "Ama", last_name: "Diallo", joined_via: "direction", anonymized_at: 1.day.ago)
    create_referral(referrer: gone, referee: create_teacher(school:, first_name: "Ali", last_name: "Bamba", joined_via: "colleague"))
    create_teacher(school:, first_name: "Ida", last_name: "Touré", joined_via: "team")
    create_teacher(school:, first_name: "Léa", last_name: "Yao", joined_via: "code")
    sign_in_as @member

    get school_path(school.public_id)

    { "Awa Koné" => "Inscription : inscription standard", "Yao Brou" => "Inscription : lien d'un collègue (Koné Awa)",
      "Ama Diallo" => "Inscription : lien de la direction", "Ali Bamba" => "Inscription : lien d'un collègue",
      "Ida Touré" => "Inscription : lien de l'équipe", "Léa Yao" => "Inscription : code d'établissement" }.each do |name, via|
      assert_select "#school_teachers li", text: /#{Regexp.escape(name)}/ do
        assert_select "p.text-xs.text-mute", text: via
      end
    end
  end

  test "CE-06: the page of a school that is not active warns that its code lets nobody sign up" do
    sign_in_as @member

    %w[draft inactive].each do |status|
      school = create_school(drena: @drena, status:)

      get school_path(school.public_id)

      assert_select "#school_code", text: /#{Regexp.escape(I18n.t("teams.schools.header.school_code_inactive"))}/
    end
  end

  test "CN-01, UDR-0046: the « Classes par niveau » block counts each level and series; its sum is the page's and the list's" do
    referential = seed_referential
    school = create_school(drena: @drena, name: "Lycée Moderne de Cocody", cycle: "both")
    sixths = (1..4).map { create_classroom(school:, level: referential[:levels]["6eme"], name: "6ème #{it}") }
    create_classroom(school:, level: referential[:levels]["tle"], series: referential[:series]["d"], name: "Tle D 1",
                     status: "archived")
    create_classroom(school:, level: referential[:levels]["6eme"], name: "6ème 9", school_year: "2020-2021")
    sign_in_as @member

    get school_path(school.public_id)

    assert_response :success
    within_block = "#school_classrooms #school_level_classrooms"
    assert_select "#{within_block} h3#school_level_classrooms_title", text: I18n.t("teams.level_classrooms.block.title")
    assert_select "#{within_block} li", 14
    assert_select "#{within_block} #level_classrooms_6eme [role=group][aria-label=?]", I18n.t("teams.level_classrooms.block.count", level: "6ème", count: 4)
    assert_select "#{within_block} #level_classrooms_tle-d [role=group][aria-label=?]", I18n.t("teams.level_classrooms.block.count", level: "Tle D", count: 1)
    assert_select "#{within_block} #level_classrooms_tle-a1 [role=group][aria-label=?]", I18n.t("teams.level_classrooms.block.count", level: "Tle A1", count: 0)
    assert_select "#{within_block} #level_classrooms_6eme dialog form[action='#{school_level_classroom_path(school.public_id, sixths.last.public_id)}'] input[name=_method][value=delete]", 1
    assert_select "#{within_block} #level_classrooms_6eme dialog h2", text: I18n.t("teams.level_classrooms.block.remove_title", name: "6ème 4")
    assert_select "#{within_block} #level_classrooms_tle-a1 button[disabled]", text: I18n.t("teams.level_classrooms.block.remove", level: "Tle A1")
    assert_select "#{within_block} #level_classrooms_tle-a1 form[action='#{school_level_classrooms_path(school.public_id)}'] input[name=series][value=a1]"
    assert_select "#{within_block} form[action='#{school_level_classrooms_path(school.public_id)}'] button[type=submit]", 14
    assert_select "#school_classrooms_title", text: I18n.t("teams.schools.show.classrooms", count: 5)

    get schools_path
    assert_select "#school_#{school.public_id} td:nth-child(7)", text: "5" # « Classes », après le code d'établissement
  end

  # UDR-0056 §3.2: the block moved to shared/_level_classrooms, shared with the direction; the team's page is unchanged.
  test "UDR-0056: the school page renders the shared « Classes par niveau » block, aimed at the team's routes" do
    school = create_school(drena: @drena)
    sign_in_as @member
    partials = []
    callback = ->(*, payload) { partials << payload[:identifier].delete_prefix("#{Rails.root}/app/views/") }

    ActiveSupport::Notifications.subscribed(callback, "render_partial.action_view") { get school_path(school.public_id) }

    assert_includes partials, "shared/_level_classrooms.html.erb"
    assert_not_includes partials, "teams/schools/_level_classrooms.html.erb"
    assert_select "#school_classrooms #school_level_classrooms"
  end

  test "UDR-0046: a draft school's block keeps « − » but offers no « + », and says why" do
    referential = seed_referential
    draft = create_school(status: "draft")
    create_classroom(school: draft, level: referential[:levels]["6eme"], name: "6ème 1")
    sign_in_as @member

    get school_path(draft.public_id)

    assert_select "#school_level_classrooms_inactive", text: I18n.t("teams.level_classrooms.block.inactive")
    assert_select "#school_level_classrooms form[action='#{school_level_classrooms_path(draft.public_id)}']", 0
    assert_select "#level_classrooms_6eme dialog form[action^='#{school_level_classrooms_path(draft.public_id)}/']"
  end

  test "UDR-0046: without any level in the referential, the block says so" do
    school = create_school(drena: @drena)
    sign_in_as @member

    get school_path(school.public_id)

    assert_select "#school_level_classrooms", text: /#{I18n.t('teams.level_classrooms.block.empty_title')}/
    assert_select "#school_level_classrooms_inactive", 0
  end

  test "a draft school page offers no « Ajouter une classe » until the school is activated" do
    draft = create_school(status: "draft")
    sign_in_as create_team_member

    get school_path(draft.public_id)

    assert_response :success
    assert_select "a[href='#{new_school_classroom_path(draft.public_id)}']", count: 0
    assert_select "#school_header a[href='#{edit_school_path(draft.public_id)}']"
  end

  test "a school without classrooms nor teachers says so; an inactive one offers no deactivation" do
    school = create_school(drena: @drena, status: "inactive")
    sign_in_as @member

    get school_path(school.public_id)

    assert_select "#school_classrooms", text: /#{I18n.t('teams.schools.show.no_classrooms')}/
    assert_select "#school_teachers", text: /#{I18n.t('teams.schools.show.no_teachers')}/
    assert_select "form[action='#{deactivate_school_path(school.public_id)}']", 0
  end

  test "the edition form opens in the modal frame, with the current values and the reminder about classrooms" do
    create_drena(name: "Bouaké")
    school = create_school(drena: @drena, name: "Lycée Moderne", sigle: "LM", school_type: "mixed", cycle: "first", status: "draft")
    sign_in_as @member

    get edit_school_path(school.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#school-modal form#school-form[action='#{school_path(school.public_id)}'] input[name=_method][value=patch]"
    assert_select "select[name='school[drena_public_id]'] option:not([value=''])", 2
    assert_select "select[name='school[drena_public_id]'] option[selected][value='#{@drena.public_id}']"
    assert_select "input[name='school[name]'][value='Lycée Moderne'][maxlength='150']"
    assert_select "input[name='school[sigle]'][value=LM][maxlength='#{Entities::School::School::SIGLE_MAX}']"
    assert_select "select[name='school[school_type]'] option:not([value=''])", 3
    assert_select "select[name='school[school_type]'] option[selected][value=mixed]", text: I18n.t("school_types.mixed")
    assert_select "select[name='school[cycle]']", 0
    assert_select "fieldset#school_cycle > legend", text: /#{Dtos::School::SchoolInput.human_attribute_name(:cycle)}/
    assert_select "fieldset#school_cycle label.min-h-tap", 2
    assert_select "label", text: I18n.t("teams.schools.cycles.first") do
      assert_select "input#school_cycle_first[type=radio][name='school[cycle]'][value=first][checked][required]"
    end
    assert_select "label", text: I18n.t("teams.schools.cycles.both") do
      assert_select "input#school_cycle_both[type=radio][value=both]:not([checked])"
    end
    assert_select "select[name='school[status]'] option[selected][value=draft]"
    assert_select "#school-form", text: /#{I18n.t('teams.schools.form.classrooms_hint')}/
  end

  test "CP-10: the national code is read on the header, edited in the form, and a taken one is refused (ADR-0063)" do
    school = create_school(drena: @drena, name: "Lycée Classique", national_code: "012345")
    other = create_school(drena: @drena, name: "Lycée Moderne")
    sign_in_as @member

    get school_path(school.public_id)
    assert_select "#school_header #school_national_code", text: /012345/
    get edit_school_path(school.public_id), headers: { "Turbo-Frame" => "modal" }
    assert_select "input[name='school[national_code]'][value='012345'][inputmode=numeric][maxlength='6']"

    patch school_path(other.public_id), params: school_params(name: "Lycée Moderne", national_code: "012345"),
                                        headers: { "Turbo-Frame" => "modal" }
    assert_response :unprocessable_entity
    assert_select "#school_national_code_error", text: error_message(:national_code, :taken)

    patch school_path(other.public_id), params: school_params(name: "Lycée Moderne", national_code: "023 456"), as: :turbo_stream
    assert_equal "023456", other.reload.national_code
  end

  test "CP-10: a school without national code shows none; the list is searched by it" do
    create_school(drena: @drena, name: "Lycée Classique", national_code: "012345")
    school = create_school(drena: @drena, name: "Lycée Moderne")
    sign_in_as @member

    get school_path(school.public_id)
    assert_select "#school_national_code", 0
    get schools_path(search: "012345")
    assert_select "tbody tr", 1
    assert_select "tbody", text: /Lycée Classique/
  end

  test "outside the frame, the edition opens as a modal over the shell; an unknown school has none" do
    school = create_school(drena: @drena)
    sign_in_as @member

    get edit_school_path(school.public_id)
    assert_select "nav"
    assert_select "turbo-frame#modal dialog#school-modal form#school-form"

    get edit_school_path("sch-inconnue")
    assert_response :not_found
    patch school_path("sch-inconnue"), params: school_params
    assert_response :not_found
    patch deactivate_school_path("sch-inconnue")
    assert_response :not_found
    delete school_path("sch-inconnue")
    assert_response :not_found
  end

  test "SC-06, SC-09: an edition answers in Turbo Stream — toast, row and header replaced — and no classroom is created or deleted" do
    school = create_school(drena: @drena, name: "Lycée Classique", school_type: "public", cycle: "both")
    classroom_ids = Array.new(3) { create_classroom(school:).id }
    bouake = create_drena(name: "Bouaké")
    sign_in_as @member

    patch school_path(school.public_id), params: school_params(drena_public_id: bouake.public_id, name: "Lycée Classique d'Abidjan",
                                                               school_type: "private", cycle: "first", status: "draft"),
                                         as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    school.reload
    assert_equal [ bouake.id, "Lycée Classique d'Abidjan", "LCA", "private", "first", "draft" ],
                 [ school.drena_id, school.name, school.sigle, school.school_type, school.cycle, school.status ]
    assert_equal classroom_ids.sort, Orm::Classroom.where(school:).order(:id).ids
    assert_equal 3, Orm::Classroom.count
    assert_select "turbo-stream[action=append][target=toasts]",
                  text: /#{I18n.t('teams.schools.update.done', name: "Lycée Classique d'Abidjan")}/
    assert_select "turbo-stream[action=replace][target=school_#{school.public_id}] tr#school_#{school.public_id}", text: /Bouaké/
    assert_select "turbo-stream[action=replace][target=school_header] #school_header", text: /#{I18n.t('teams.schools.cycles.first')}/
    # IE-08: the header re-rendered from a SchoolsQuery::Row keeps the team's invitation link.
    assert_select "turbo-stream[action=replace][target=school_header] #school_code a#school_code_link[href=?]",
                  teacher_invite_link_url(school.team_invite_token)
    assert_select "turbo-stream[action=replace][target=school_level_classrooms] #school_level_classrooms" # UDR-0046
    assert_equal "school.changed", Orm::AuditEvent.sole.action
  end

  test "an invalid edition comes back in 422 in the modal, with its errors and the typed values" do
    school = create_school(drena: @drena, name: "Lycée Classique")
    create_school(drena: @drena, name: "Lycée Moderne")
    sign_in_as @member

    patch school_path(school.public_id), params: school_params(name: "", cycle: "second"), headers: { "Turbo-Frame" => "modal" }
    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog#school-modal form#school-form"
    assert_select "#school_name_error", text: error_message(:name, :blank)
    assert_select "fieldset#school_cycle > #school_cycle_error", text: error_message(:cycle, :inclusion)
    assert_select "input[name='school[cycle]'][checked]", 0
    assert_select "input[name='school[cycle]'][aria-invalid=true][aria-describedby=school_cycle_error]", 2
    assert_select "input[name='school[sigle]'][value=LCA]"

    patch school_path(school.public_id), params: school_params(name: "Lycée Moderne")
    assert_response :unprocessable_entity
    assert_select "#school_name_error", text: error_message(:name, :taken)

    patch school_path(school.public_id), params: school_params(drena_public_id: "drena-disparue")
    assert_response :unprocessable_entity
    assert_select "#school_drena_public_id_error", text: error_message(:drena_public_id, :inclusion)
    assert_equal "Lycée Classique", school.reload.name
  end

  test "without Turbo, an edition leads back to the list with a notice" do
    school = create_school(drena: @drena)
    sign_in_as @member

    patch school_path(school.public_id), params: school_params

    assert_redirected_to schools_path
    assert_equal I18n.t("teams.schools.update.done", name: "Lycée Classique d'Abidjan"), flash[:notice]
  end

  test "SC-07: deactivating keeps the school, its classrooms and students, and takes it out of the teacher sign-up" do
    school = create_school(drena: @drena, name: "Lycée Classique")
    classroom = create_classroom(school:)
    create_student(classroom:)
    sign_in_as @member
    options = -> { Queries::School::SchoolOptionsQuery.new.schools_for(drena_public_id: @drena.public_id).map(&:name) }
    assert_equal [ "Lycée Classique" ], options.call

    patch deactivate_school_path(school.public_id), as: :turbo_stream

    assert_response :success
    assert_equal "inactive", school.reload.status
    assert Orm::Classroom.exists?(classroom.id)
    assert_equal 1, Orm::ClassroomStudent.count
    assert_empty options.call
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t('teams.schools.deactivate.done', name: 'Lycée Classique')}/
    assert_select "turbo-stream[action=replace][target=school_#{school.public_id}] tr", text: /#{I18n.t('school_statuses.inactive')}/
    assert_select "turbo-stream[action=replace][target=school_header] #school_header", text: /#{I18n.t('school_statuses.inactive')}/
    assert_select "turbo-stream[action=replace][target=school_level_classrooms] #school_level_classrooms_inactive" # UDR-0046
  end

  test "without Turbo, a deactivation leads back to the list with a notice" do
    school = create_school(drena: @drena, name: "Lycée Classique")
    sign_in_as @member

    patch deactivate_school_path(school.public_id)

    assert_redirected_to schools_path
    assert_equal I18n.t("teams.schools.deactivate.done", name: "Lycée Classique"), flash[:notice]
  end

  test "SC-07: deleting an unused school removes it with its classrooms, and its row" do
    school = create_school(drena: @drena)
    create_classroom(school:)
    sign_in_as @member

    delete school_path(school.public_id), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t('teams.schools.destroy.done')}/
    assert_select "turbo-stream[action=remove][target=school_#{school.public_id}]"
    assert_select "turbo-stream[action=refresh]:not([request-id])"
    assert_not Orm::School.exists?(school.id)
    assert_not Orm::Classroom.exists?
  end

  test "B1: deleting a school with a join request (even refused) or a referral is refused in 422, never a 500 (ADR-0063)" do
    requested = create_join_request(school: create_school(drena: @drena), status: "rejected").school
    sponsored = create_school(drena: @drena)
    create_referral(school_id: sponsored.id)
    sign_in_as @member

    [ requested, sponsored ].each do |school|
      delete school_path(school.public_id), as: :turbo_stream

      assert_response :unprocessable_entity
      assert Orm::School.exists?(school.id)
    end
  end

  test "SC-07: deleting a school whose classroom has a student is refused — deactivate it instead — and nothing is deleted" do
    school = create_school(drena: @drena)
    create_student(classroom: create_classroom(school:))
    sign_in_as @member

    delete school_path(school.public_id), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: /#{I18n.t('teams.schools.destroy.referenced')}/
    assert_select "turbo-stream[action=replace][target=school_#{school.public_id}] tr#school_#{school.public_id}"
    assert_select "turbo-stream[action=refresh]", 0
    assert Orm::School.exists?(school.id)
    assert_equal 1, Orm::Classroom.count
  end

  test "without Turbo, a deletion leads back to the list, with a notice or the reason of the refusal" do
    used = create_school(drena: @drena)
    create_teacher(school: used)
    unused = create_school(drena: @drena)
    sign_in_as @member

    delete school_path(unused.public_id)
    assert_redirected_to schools_path
    assert_equal I18n.t("teams.schools.destroy.done"), flash[:notice]

    delete school_path(used.public_id)
    assert_redirected_to schools_path
    assert_equal I18n.t("teams.schools.destroy.referenced"), flash[:alert]
  end

  # ── Finitions UX (UDR-0054, Lot D1) ──────────────────────────────────────────────────────────────────────────────

  test "FU-01: the list is titled « Établissements · Équipe · Lnclass »" do
    sign_in_as @member

    get schools_path

    assert_select "title", text: "Établissements · Équipe · Lnclass"
  end

  test "FU-45, FU-46: the filters form searches while typing and sends its lists on change, and keeps « Filtrer » without JavaScript" do
    sign_in_as @member

    get schools_path

    assert_select "form#schools-filters[method=get][action='#{schools_path}'][data-controller=search]" \
                  "[data-turbo-frame=schools][data-turbo-action=advance]" \
                  "[role=search][aria-label='#{I18n.t('teams.schools.filters.label')}']" do
      assert_select "input#filter_search[type=search][name=search][data-action='input->search#queue']"
      %w[drena school_type cycle status].each do |name|
        assert_select "select#filter_#{name}[name=#{name}][data-action='change->search#submit']"
      end
      assert_select "button[type=submit][data-search-target=button]:not([hidden])", text: I18n.t("teams.schools.filters.submit")
    end
    assert_select "turbo-frame#schools.transition-opacity.aria-busy\\:opacity-50"
    assert_select "turbo-frame#schools #schools_total[aria-live=polite]"
  end

  test "FU-46: without JavaScript, the search sent by « Filtrer » renders the whole filtered page, accents ignored" do
    create_school(drena: @drena, name: "Lycée Moderne de Cocody")
    create_school(drena: @drena, name: "Collège Sainte-Marie")
    sign_in_as @member

    get schools_path(search: "COC", drena: @drena.public_id)

    assert_response :success
    assert_select "h1", text: I18n.t("teams.schools.index.title")
    assert_select "input#filter_search[value=COC]"
    assert_select "#schools_list tr", 1
    assert_select "#schools_list tr", text: /Lycée Moderne de Cocody/
    assert_select "#schools_total", text: I18n.t("teams.schools.index.total", count: 1)
  end

  test "UDR-0054 §3.4: the status column of the list explains the statuses in a tip" do
    create_school(drena: @drena)
    sign_in_as @member

    get schools_path

    assert_select "thead th details summary .sr-only", text: I18n.t("components.info_tip.label",
                                                                   label: I18n.t("teams.schools.index.columns.status"))
    assert_select "thead th details", text: /#{Regexp.escape(I18n.t('shared.info_tips.school_status'))}/
  end

  test "FU-09: « Établissements » leads back to the filtered list the school was opened from" do
    school = create_school(drena: @drena, name: "Lycée Moderne de Cocody")
    sign_in_as @member
    filtered = schools_path(search: "coc", drena: @drena.public_id)

    get school_path(school.public_id), headers: { "Referer" => "http://www.example.com#{filtered}" }

    assert_select "main nav[aria-label='#{I18n.t('components.back_link.label')}'] a[href='#{filtered}']",
                  text: I18n.t("teams.schools.show.back")
    assert_select "#school_header nav", 0
    assert_select "nav[aria-label='#{I18n.t('components.back_link.label')}'] ~ #school_header"
  end

  test "FU-09: opened from a direct link, another page or another site, « Établissements » leads to the unfiltered list" do
    school = create_school(drena: @drena, name: "Lycée Moderne de Cocody")
    sign_in_as @member
    back = "nav[aria-label='#{I18n.t('components.back_link.label')}'] a"

    [ nil, "http://www.example.com#{team_home_path}?search=coc", "http://evil.example#{schools_path}?search=coc" ].each do |referer|
      get school_path(school.public_id), headers: { "Referer" => referer }.compact

      assert_select "#{back}[href='#{schools_path}']", { text: I18n.t("teams.schools.show.back") }, "Referer : #{referer.inspect}"
    end
  end

  test "UDR-0054 §3.1, §3.4: a school's page is titled by its name; its code and status are explained in tips" do
    school = create_school(drena: @drena, name: "Lycée Moderne de Cocody")
    sign_in_as @member

    get school_path(school.public_id)

    assert_select "title", text: "Lycée Moderne de Cocody · Équipe · Lnclass"
    assert_select "#school_code details", text: /#{Regexp.escape(I18n.t('teams.schools.header.school_code_tip'))}/
    assert_select "#school_code details summary .sr-only",
                  text: I18n.t("components.info_tip.label", label: I18n.t("teams.schools.header.school_code"))
    assert_select "#school_header details", text: /#{Regexp.escape(I18n.t('shared.info_tips.school_status'))}/
  end

  test "UDR-0054 §3.1: the edition modal carries its title, also when opened by its URL" do
    school = create_school(drena: @drena)
    sign_in_as @member

    get edit_school_path(school.public_id)

    assert_select "title", text: "Modifier l'établissement · Équipe · Lnclass"
    assert_select "[data-modal-document-title-value=\"Modifier l'établissement · Équipe · Lnclass\"] dialog#school-modal"
  end

  test "ID-18 (UDR-0070 §3.4, §3.5): « Direction » heads the teachers' section, then « Directions retirées », with « Restaurer »" do
    school = create_school(drena: @drena)
    kofi = create_school_admin(school:, first_name: "Kofi", last_name: "Yao", joined_via: "code", joined_at: 1.day.ago)
    author = create_team_member(team_role: "field", second_factor: false, first_name: "Awa", last_name: "Bamba")
    aya = create_school_admin(school:, first_name: "Aya", last_name: "Koné", joined_via: "code", archived_at: Time.zone.local(2026, 9, 1, 10),
                              archived_by: author)
    create_teacher(school:, first_name: "Moussa", last_name: "Traoré")
    sign_in_as create_team_member(team_role: "field")

    get school_path(school.public_id)

    assert_select "#school_teachers > div:first-child #school_staff" do
      assert_select "p#school_staff_places", text: I18n.t("shared.school_staff.subtitle", used: 1, cap: 3)
      assert_select "li", 1
      assert_select "li#school_staff_#{kofi.public_id} button[aria-haspopup=menu]"
      assert_select "form[action='#{school_staff_member_path(school.public_id, kofi.public_id)}']"
    end
    assert_select "#school_staff + #school_archived_staff" do
      assert_select "h2", text: I18n.t("teams.schools.archived_staff.title")
      assert_select "li#school_archived_staff_#{aya.public_id}", text: /Aya Koné/ do
        assert_select "p", text: /Retirée le 1er septembre 2026 par Awa Bamba\s+· Supprimée le 1er octobre 2026/
        assert_select "form[action='#{school_staff_member_restoration_path(school.public_id, aya.public_id)}'] button",
                      text: I18n.t("teams.schools.archived_staff.restore")
      end
    end
    assert_select "#school_teachers li", text: /Moussa Traoré/
  end

  test "ID-21: a content member sees « Direction » without ⋮ menu, and « Directions retirées » without « Restaurer »" do
    school = create_school(drena: @drena)
    kofi = create_school_admin(school:, joined_at: 30.days.ago)
    create_school_admin(school:, archived_at: 1.day.ago)
    sign_in_as create_team_member(team_role: "content")

    get school_path(school.public_id)

    assert_select "li#school_staff_#{kofi.public_id}"
    assert_select "#school_staff button[aria-haspopup=menu]", 0
    assert_select "#school_archived_staff li", 1
    assert_select "#school_archived_staff form", 0
  end

  test "UDR-0070 §3.5: without removed direction, no « Directions retirées » card, only the empty target of the stream" do
    school = create_school(drena: @drena)
    sign_in_as @member

    get school_path(school.public_id)

    assert_select "#school_staff", text: /#{I18n.t('shared.school_staff.empty')}/
    assert_select "div#school_archived_staff:empty"
    assert_select "#school_teachers h2", text: I18n.t("teams.schools.archived_staff.title"), count: 0
  end

  # Chantier politique-cache, lot E (ADR-0067) : les icônes des lignes (menu ⋮, modales) sont dessinées une fois, dans le
  # frame « schools » qu'un filtre ou une page remplace seul ; celles de la fiche, une fois pour la page.
  test "the list and a school's page take their icons from symbols drawn once" do
    school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan")
    create_school(drena: @drena, name: "Lycée Moderne de Cocody")
    create_teacher(school:, first_name: "Awa", last_name: "Koné", material: create_material(name: "SVT", category: "science"))
    sign_in_as @member

    get schools_path
    assert_icons_drawn_once "turbo-frame#schools"

    get schools_path(search: "Cocody"), headers: { "Turbo-Frame" => "schools" }
    assert_icons_drawn_once "turbo-frame#schools"

    get school_path(school.public_id)
    assert_icons_drawn_once "#main"
  end

  # Lot E3 (chantier politique-cache) : les confirmations de la liste ne sont plus copiées dans chaque ligne. Elles arrivent
  # dans le frame « modal », avec le même titre, le même texte, les mêmes boutons et le même envoi ; sans frame, la même
  # adresse est une page complète. Un établissement inconnu, ou déjà inactif pour la désactivation, répond 404.
  test "the deactivation and deletion confirmations are read on demand in the modal frame, or as a full page" do
    school = create_school(drena: @drena, name: "Lycée Classique")
    sign_in_as @member

    get deactivation_school_path(school.public_id), headers: { "Turbo-Frame" => "modal" }
    assert_response :success
    assert_select "turbo-frame#modal dialog#deactivate-school-#{school.public_id}[open]" do
      assert_select "h2", text: I18n.t("teams.schools.deactivation.title", name: "Lycée Classique")
      assert_select "form#deactivate-school-form-#{school.public_id}[action='#{deactivate_school_path(school.public_id)}'] " \
                    "input[name=_method][value=patch]"
      assert_select "p", text: I18n.t("teams.schools.deactivation.warning")
      assert_select "button[type=submit][form=deactivate-school-form-#{school.public_id}]", text: I18n.t("teams.schools.deactivation.confirm")
      assert_select "button[data-action='modal#close']", text: I18n.t("teams.schools.deactivation.cancel")
    end
    assert_select "#back-to-schools", 0

    get deletion_school_path(school.public_id), headers: { "Turbo-Frame" => "modal" }
    assert_response :success
    assert_select "turbo-frame#modal dialog#delete-school-#{school.public_id}[open]" do
      assert_select "h2", text: I18n.t("teams.schools.deletion.title", name: "Lycée Classique")
      assert_select "form#delete-school-form-#{school.public_id}[action='#{school_path(school.public_id)}'] input[name=_method][value=delete]"
      assert_select "p", text: I18n.t("teams.schools.deletion.warning")
      assert_select "button[type=submit][form=delete-school-form-#{school.public_id}]", text: I18n.t("teams.schools.deletion.confirm")
    end

    get deletion_school_path(school.public_id)
    assert_response :success
    assert_select "main#main a#back-to-schools[href='#{schools_path}']", text: I18n.t("teams.schools.deletion.back")
    assert_select "main#main turbo-frame#modal dialog#delete-school-#{school.public_id}[open]"

    get deactivation_school_path("sch-inconnue")
    assert_response :not_found
    get deletion_school_path("sch-inconnue")
    assert_response :not_found
    get deactivation_school_path(create_school(drena: @drena, status: "inactive").public_id)
    assert_response :not_found
  end

  test "a refused deletion closes the confirmation of the modal frame" do
    school = create_school(drena: @drena)
    create_student(classroom: create_classroom(school:))
    sign_in_as @member

    delete school_path(school.public_id), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=update][target=modal] template", text: ""
    assert Orm::School.exists?(school.id)
  end
end
