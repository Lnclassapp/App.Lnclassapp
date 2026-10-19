require "test_helper"

# ADR-0096, UDR-0104, RM-01, RM-06 to RM-09, RM-15, RM-16, RM-19, RM-22: the admin of the team launches a mass regeneration
# from the list (filtered selection) or from the card of a school (its classrooms); nobody else may.
class Teams::CodeRegenerationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @admin = create_team_member(team_role: "admin")
    @abidjan = create_drena(name: "Abidjan 1")
    @lycee = create_school(drena: @abidjan, name: "Lycée Moderne de Cocody")
    @college = create_school(drena: @abidjan, name: "Collège Saint Paul", school_type: "private")
    @level = create_level
    2.times { create_classroom(school: @lycee, level: @level, name: "6e #{it + 1}") }
    create_classroom(school: @college, level: @level, name: "6e 1")
  end

  def regenerate(target: "school_codes", selection: { drena: @abidjan.public_id }, typed_count: nil, current_year_only: "1", as: nil)
    post code_regenerations_path, params: { code_regeneration: { target:, selection:, typed_count:, current_year_only: } }, as:
  end

  test "RM-09, RM-22: content, field, a direction and a teacher receive 403 on both actions, for both targets" do
    [ create_team_member(team_role: "content"), create_team_member(team_role: "field"), create_school_admin(school: @lycee),
      create_teacher(school: @lycee) ].each do |user|
      sign_in_as user
      %w[school_codes classroom_links].each do |target|
        get new_code_regeneration_path(target:, drena: @abidjan.public_id)
        assert_response :forbidden
        assert_no_enqueued_jobs { regenerate(target:) }
        assert_response :forbidden
      end
      sign_out
    end
    assert_equal 0, Orm::ImportReport.count
  end

  test "RM-09, RM-22: content and field see neither the « Codes » menu of the list nor the entry of the card" do
    %w[content field].each do |team_role|
      sign_in_as create_team_member(team_role:)

      get schools_path
      assert_select "#schools-codes-menu", 0
      get school_path(@lycee.public_id)
      assert_select "a[href*='code-regenerations']", 0
      sign_out
    end
  end

  test "the admin sees the « Codes » menu right of « Classes », with both actions carrying the filters of the list" do
    sign_in_as @admin

    get schools_path(drena: @abidjan.public_id, status: "", search: "lycée")

    assert_select "button[aria-controls=schools-codes-menu][aria-label='Codes et liens des classes']", text: /Codes/
    assert_select "#schools-codes-menu[role=menu]" do
      assert_select "a[role=menuitem][data-turbo-frame=modal][href=?]",
                    new_code_regeneration_path(target: "school_codes", drena: @abidjan.public_id, search: "lycée"),
                    text: "Régénérer les codes d'établissement"
      assert_select "a[role=menuitem][data-turbo-frame=modal][href=?]",
                    new_code_regeneration_path(target: "classroom_links", drena: @abidjan.public_id, search: "lycée"),
                    text: "Régénérer les liens des classes"
    end
    assert_operator response.body.index('aria-controls="schools-classrooms-menu"'), :<, response.body.index('aria-controls="schools-codes-menu"')
  end

  test "RM-01: a filter changed in the list frame replaces the « Codes » menu, so that it carries the selection shown" do
    sign_in_as @admin

    get schools_path(drena: @abidjan.public_id), headers: { "Turbo-Frame" => "schools" }

    assert_select "turbo-frame#schools turbo-stream[action=replace][target=schools-codes-menu-slot] template" do
      assert_select "a[role=menuitem][href=?]", new_code_regeneration_path(target: "school_codes", drena: @abidjan.public_id)
    end

    sign_in_as create_team_member(team_role: "content")
    get schools_path(drena: @abidjan.public_id), headers: { "Turbo-Frame" => "schools" }
    assert_select "turbo-stream", 0
  end

  test "RM-07: an empty selection disables both actions, with the reason" do
    sign_in_as @admin

    get schools_path(search: "introuvable")

    assert_select "#schools-codes-menu [role=menuitem][aria-disabled=true]", 2
    assert_select "#schools-codes-menu [role=menuitem]", text: "Régénérer les codes d'établissement (aucun établissement)"
    assert_select "#schools-codes-menu a[role=menuitem]", 0
  end

  test "RM-16: the card offers the links of its classrooms to the admin, in the modal frame" do
    sign_in_as @admin

    get school_path(@lycee.public_id)

    assert_select "#school-header-actions a[role=menuitem][data-turbo-frame=modal][href=?]",
                  new_code_regeneration_path(target: "classroom_links", school: @lycee.public_id), text: "Régénérer les liens des classes"
  end

  test "one DRENA: the modal counts the schools, names the DRENA, and asks no number" do
    sign_in_as @admin

    get new_code_regeneration_path(target: "school_codes", drena: @abidjan.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog#code-regeneration-modal[open]" do
      assert_select "h2", "Régénérer les codes d'établissement"
      assert_select "#code_regeneration_question", "Régénérer le code de 2 établissements de la DRENA Abidjan 1 ?"
      assert_select "#code_regeneration_question strong", 2
      assert_select "#code_regeneration_rules li", 3
      assert_select "input[name='code_regeneration[typed_count]']", 0
      assert_select "input[type=hidden][name='code_regeneration[selection][drena]'][value=?]", @abidjan.public_id
      assert_select "form#code-regeneration-form[data-turbo-frame=_top]"
      assert_select "button[type=submit][form=code-regeneration-form]", text: /Régénérer les codes/
    end
    assert_select "#back-to-schools", 0
    assert_no_match @lycee.school_code, response.body
  end

  test "RM-06: without a DRENA, the modal recalls the other filters and asks to type the number" do
    sign_in_as @admin

    get new_code_regeneration_path(target: "school_codes", school_type: "private", search: "saint")

    assert_select "#back-to-schools"
    assert_select "#code_regeneration_question", "Régénérer le code de 1 établissements ?"
    assert_select "#code_regeneration_filters", "Filtres : Privé · « saint »"
    assert_select "label[for=code_regeneration_typed_count]", text: /\ATapez 1 pour confirmer/
    assert_select "input#code_regeneration_typed_count[inputmode=numeric][autocomplete=off][required]"
  end

  test "RM-19: the links count the classrooms of the year by default, and every year on demand" do
    create_classroom(school: @lycee, level: @level, name: "6e 1", school_year: current_school_year(on: 1.year.ago.to_date))
    sign_in_as @admin

    get new_code_regeneration_path(target: "classroom_links", school: @lycee.public_id)

    assert_select "#code_regeneration_question", "Régénérer le lien de 2 classes de Lycée Moderne de Cocody ?"
    assert_select "#code_regeneration_year", text: /Classes de l'année #{current_school_year} seulement\./
    assert_select "#code_regeneration_year a[data-turbo-frame=modal][href=?]",
                  new_code_regeneration_path(target: "classroom_links", school: @lycee.public_id, all_years: "1"), text: "Inclure les années passées"
    assert_select "input[type=hidden][name='code_regeneration[current_year_only]'][value='1']"

    get new_code_regeneration_path(target: "classroom_links", school: @lycee.public_id, all_years: "1")

    assert_select "#code_regeneration_question", "Régénérer le lien de 3 classes de Lycée Moderne de Cocody ?"
    assert_select "#code_regeneration_year", text: /Classes de toutes les années\./
    assert_select "input[type=hidden][name='code_regeneration[current_year_only]'][value='0']"
  end

  test "a school without an active classroom: the modal says so, without a confirm button" do
    empty = create_school(drena: @abidjan)
    sign_in_as @admin

    get new_code_regeneration_path(target: "classroom_links", school: empty.public_id)

    assert_select "#code_regeneration_empty[role=alert]", text: "Aucune classe à régénérer."
    assert_select "button[type=submit]", 0
  end

  test "an unknown target is 404" do
    sign_in_as @admin

    get new_code_regeneration_path(target: "users")
    assert_response :not_found
    regenerate(target: "users")
    assert_response :not_found
  end

  test "RM-01: one DRENA, the launch creates the report, queues its job and leads to the report with a toast" do
    sign_in_as @admin

    assert_enqueued_with(job: School::RegenerateSchoolCodesJob) { regenerate }

    report = Orm::ImportReport.sole
    assert_equal [ "school_codes", "queued", @admin.id, nil ], report.attributes.values_at("kind", "status", "imported_by_id", "checksum_sha256")
    assert_equal({ "selection" => { "drena" => @abidjan.public_id, "school_year" => nil }, "expected_count" => 2 }, report.details)
    assert_redirected_to teams_import_path(report.public_id)
    assert_response :see_other
    assert_equal "Régénération des codes lancée.", flash[:notice]
  end

  test "RM-15, RM-16: the links of the classrooms of a school, then of a DRENA, are launched without a number" do
    sign_in_as @admin

    assert_enqueued_with(job: Classroom::RegenerateClassroomLinksJob) { regenerate(target: "classroom_links", selection: { school: @lycee.public_id }) }

    assert_equal 2, Orm::ImportReport.sole.details["expected_count"]
    assert_equal "Régénération des liens des classes lancée.", flash[:notice]
  end

  test "RM-06: a wrong typed number is refused in the modal, recounted, and nothing is created" do
    sign_in_as @admin

    assert_no_enqueued_jobs { regenerate(selection: { status: "active" }, typed_count: "1", as: :turbo_stream) }

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=modal]"
    assert_match "Tapez 2 pour confirmer.", response.body
    assert_equal 0, Orm::ImportReport.count

    regenerate(selection: { status: "active" }, typed_count: "2")
    assert_response :see_other
  end

  test "RM-07: a forced launch on an empty selection is 422 « Aucun établissement à régénérer. », in HTML too" do
    sign_in_as @admin

    regenerate(selection: { search: "introuvable" }, typed_count: "0")

    assert_response :unprocessable_entity
    assert_select "#code_regeneration_empty", text: "Aucun établissement à régénérer."
    assert_equal 0, Orm::ImportReport.count
  end

  test "RM-08: while a regeneration of the same kind runs, the admin is led to it with an information toast" do
    running = create_import_report(kind: "school_codes", checksum_sha256: nil, status: "importing", started_at: Time.current)
    create_import_report(kind: "classroom_links", checksum_sha256: nil, status: "completed", finished_at: Time.current,
                                       created_at: 1.minute.ago)
    running.update_columns(created_at: 1.hour.ago)
    sign_in_as @admin

    assert_no_enqueued_jobs { regenerate }

    assert_equal 1, Orm::ImportReport.where(kind: "school_codes").count
    assert_redirected_to teams_import_path(running.public_id)
    follow_redirect!
    assert_select "#toasts [data-toast-type=info]" do
      assert_select "p.font-semibold", text: "Régénération déjà en cours"
      assert_select "p.text-mute", text: "Une régénération des codes est déjà en cours : voici son avancement."
    end
  end

  test "a job the queue refuses: the report is failed with its reason, nothing stays queued, the admin is told to retry" do
    sign_in_as @admin

    stub_any_instance(Repositories::Catalog::ImportQueue, :enqueue, ->(**) { false }) { regenerate }

    report = Orm::ImportReport.sole
    assert_equal "failed", report.status
    assert_equal [ "not_enqueued" ], report.import_errors.pluck("code")
    assert_redirected_to teams_imports_path
    assert_response :see_other
    assert_equal "La régénération n'a pas pu être lancée. Réessayez dans un instant.", flash[:alert]
    assert_enqueued_jobs 0
  end
end
