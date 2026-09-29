require "test_helper"

# CA-16, CA-18, UDR-0006, UDR-0032: the levels of the referential, managed by the team in a modal, without a page reload.
class Teams::LevelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
  end

  def level_params(name: "6ème", position: "1", cycle: "first") = { level: { name:, position:, cycle: } }

  # PRD §4: messages are compared through their locale key, never written out in the test.
  def tl(key, **) = I18n.t("teams.levels.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def taken(field) = I18n.t("activemodel.errors.models.dtos/catalog/level_input.attributes.#{field}.taken")

  test "a teacher receives 403 on every action, and nothing is written" do
    level = create_level(name: "Tle", position: 7)
    sign_in_as create_teacher

    get levels_path
    assert_response :forbidden
    get new_level_path
    assert_response :forbidden
    get edit_level_path(level.slug)
    assert_response :forbidden
    post levels_path, params: level_params, as: :turbo_stream
    assert_response :forbidden
    patch level_path(level.slug), params: level_params(name: "Terminale"), as: :turbo_stream
    assert_response :forbidden
    delete level_path(level.slug), as: :turbo_stream
    assert_response :forbidden

    assert_equal [ "Tle" ], Orm::Level.pluck(:name)
  end

  test "a blank production has no level, and says so" do
    sign_in_as @member

    get levels_path

    assert_response :success
    assert_select "h1", tl("index.title")
    assert_select "#levels tr", 0
    assert_select "#levels_empty", text: including(tl("index.empty_title"))
    assert_select "a[data-turbo-frame=modal][href='#{new_level_path}']", text: including(tl("index.new"))
  end

  test "the list follows the positions, with each level's code, series and usage" do
    tle = create_level(name: "Tle", position: 7, cycle: "second")
    sixth = create_level(name: "6ème", position: 1, cycle: "first")
    link_level_series(level: tle, series: create_series(name: "D"))
    create_classroom(level: tle)
    Orm::ClassroomPlanEntry.create!(school_type: "public", level: sixth, count: 4)
    sign_in_as @member

    get levels_path

    assert_select "#levels tr", 2
    assert_select "#levels tr:first-child#level_6eme", text: /6ème\s+6eme\s+1\s+#{tl('cycles.first')}/
    assert_select "#level_tle", text: /#{tl('cycles.second')}\s+D\s+1\s+0/
    assert_select "#level_tle [role=menu] a[role=menuitem][data-turbo-frame=modal][href='#{edit_level_path('tle')}']", text: including(tl("level_row.edit"))
    assert_select "#level_tle dialog#delete-level-tle form#delete-level-tle-form[action='#{level_path('tle')}']" do
      assert_select "input[name=_method][value=delete]", 1
    end
    assert_select "#levels_empty", 0
  end

  test "the list leads to the barème, and flags a level without any positive count in it (ADR-0058)" do
    sixth = create_level(name: "6ème", position: 1, cycle: "first")
    create_level(name: "Sixième bis", position: 2, cycle: "first")
    Orm::ClassroomPlanEntry.create!(school_type: "public", level: sixth, count: 4)
    sign_in_as @member

    get levels_path

    assert_select "#levels-generation-help", text: including(tl("index.generation_help"))
    assert_select "#levels-generation-help a[href='#{classroom_plan_path}']", text: tl("index.classroom_plan_link")
    # UDR-0054 §3.4 (FU-22): the badge is followed by an info tip « Aide : Hors barème », and nothing carries a title.
    assert_select "#level_sixieme-bis [data-generation=outside]", text: including(tl("level_row.outside_generation")) do
      assert_select "details summary .sr-only", text: "Aide : #{tl("level_row.outside_generation")}"
      assert_select "details div", text: tl("level_row.outside_generation_tip")
    end
    assert_select "#level_sixieme-bis [title]", 0
    assert_select "#level_6eme"
    assert_select "#level_6eme [data-generation]", 0
  end

  test "the creation form opens in the modal frame, with the next position" do
    create_level(name: "6ème", position: 1, cycle: "first")
    sign_in_as @member

    get new_level_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#level-modal form#level-form[action='#{levels_path}']" do
      assert_select "input[name='level[name]'][maxlength='20']"
      assert_select "#level_name_hint", text: including(tl("new.name_hint"))
      assert_select "input[name='level[position]'][value='2']"
      assert_select "select[name='level[cycle]']", 0
      assert_select "fieldset#level_cycle > legend", text: /#{Dtos::Catalog::LevelInput.human_attribute_name(:cycle)}/
      assert_select "fieldset#level_cycle label.min-h-tap", 2
      assert_select "label", text: tl("cycles.first") do
        assert_select "input#level_cycle_first[type=radio][name='level[cycle]'][value=first][checked][required]"
      end
      assert_select "label", text: tl("cycles.second") do
        assert_select "input#level_cycle_second[type=radio][value=second]:not([checked])"
      end
    end
    assert_select "button[type=submit][form=level-form]", text: tl("new.submit")
  end

  test "a created level answers in Turbo Stream: toast, and the table replaced in position order" do
    create_level(name: "5ème", position: 2, cycle: "first")
    sign_in_as @member

    post levels_path, params: level_params, as: :turbo_stream

    level = Orm::Level.find_by!(name: "6ème")
    assert_equal [ "6eme", 1, "first" ], [ level.slug, level.position, level.cycle ]
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("create.created", name: "6ème"))
    assert_select "turbo-stream[action=remove][target=levels_empty]", 1
    assert_select "turbo-stream[action=replace][target=levels] tbody#levels tr", 2
    assert_select "turbo-stream[action=replace][target=levels] tr:first-child#level_6eme"
    assert_equal [ "taxonomy.changed", @member.id, "Level", level.id ],
                 Orm::AuditEvent.where(action: "taxonomy.changed").pluck(:action, :actor_id, :subject_type, :subject_id).sole
    # D1 (owner, 2026-09-28): 6ème gets its barème defaults, and the row no longer says « Hors barème ».
    assert_equal({ "private" => 2, "public" => 4 }, Orm::ClassroomPlanEntry.where(level:).pluck(:school_type, :count).to_h)
    assert_select "turbo-stream[action=replace][target=levels] #level_6eme [data-generation]", 0
  end

  test "an invalid form reopens in the modal (422), with its errors and the values typed" do
    sign_in_as @member

    post levels_path, params: level_params(name: "a" * 21, position: "sept", cycle: ""), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog#level-modal[data-modal-target=dialog] form#level-form" do
      assert_select "input[name='level[name]'][value='#{'a' * 21}'][aria-invalid=true]"
      assert_select "input[name='level[position]'][value=sept][aria-invalid=true]"
      assert_select "#level_position_error", text: including(I18n.t("errors.messages.not_a_number"))
      assert_select "fieldset#level_cycle > #level_cycle_error", text: including(I18n.t("errors.messages.inclusion"))
      assert_select "input[name='level[cycle]'][checked]", 0
      assert_select "input[name='level[cycle]'][aria-invalid=true][aria-describedby=level_cycle_error]", 2
    end
    assert_equal 0, Orm::Level.count
  end

  test "a negative position is refused by the entity, in the modal" do
    sign_in_as @member

    post levels_path, params: level_params(position: "-1"), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "#level_position_error", text: including(I18n.t("errors.messages.greater_than_or_equal_to", count: 0))
  end

  test "a name or a position already taken is refused on its field" do
    create_level(name: "6ème", position: 1, cycle: "first")
    sign_in_as @member

    post levels_path, params: level_params(position: "2"), as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "#level_name_error", text: including(taken(:name))

    post levels_path, params: level_params(name: "5ème"), as: :turbo_stream
    assert_select "#level_position_error", text: including(taken(:position))
    assert_equal 1, Orm::Level.count
  end

  test "without Turbo, a creation leads back to the list with a notice" do
    sign_in_as @member

    post levels_path, params: level_params

    assert_redirected_to levels_path
    assert_equal tl("create.created", name: "6ème"), flash[:notice]
  end

  test "the edit form opens in the modal, filled in, with its frozen code" do
    create_level(name: "6ème", position: 1, cycle: "first")
    sign_in_as @member

    get edit_level_path("6eme"), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal form#level-form[action='#{level_path('6eme')}']" do
      assert_select "input[name=_method][value=patch]"
      assert_select "input[name='level[name]'][value='6ème']"
      assert_select "input[name='level[position]'][value='1']"
      assert_select "input#level_cycle_first[type=radio][checked]"
      assert_select "input#level_cycle_second[type=radio]:not([checked])"
    end
    assert_select "#level-code", text: /6eme/
    assert_select "#level-code [data-generation]", 0
  end

  test "an unknown level has no edit form, and cannot be updated or deleted" do
    sign_in_as @member

    get edit_level_path("inconnu")
    assert_response :not_found
    patch level_path("inconnu"), params: level_params, as: :turbo_stream
    assert_response :not_found
    delete level_path("inconnu"), as: :turbo_stream
    assert_response :not_found
  end

  test "renaming a level keeps its slug, and answers in Turbo Stream" do
    create_level(name: "6ème", position: 1, cycle: "first")
    sign_in_as @member

    patch level_path("6eme"), params: level_params(name: "Sixième"), as: :turbo_stream

    assert_equal [ "Sixième", "6eme" ], Orm::Level.pick(:name, :slug)
    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("update.updated", name: "Sixième"))
    assert_select "turbo-stream[action=replace][target=levels] #level_6eme", text: /Sixième/
  end

  test "an invalid update reopens the edit modal (422)" do
    create_level(name: "6ème", position: 1, cycle: "first")
    sign_in_as @member

    patch level_path("6eme"), params: level_params(name: ""), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal form#level-form[action='#{level_path('6eme')}'] #level_name_error"
    assert_equal "6ème", Orm::Level.pick(:name)
  end

  test "without Turbo, an update leads back to the list with a notice" do
    create_level(name: "6ème", position: 1, cycle: "first")
    sign_in_as @member

    patch level_path("6eme"), params: level_params(name: "Sixième")

    assert_redirected_to levels_path
    assert_equal tl("update.updated", name: "Sixième"), flash[:notice]
  end

  test "an unused level is deleted: toast and its row removed" do
    create_level(name: "6ème", position: 1, cycle: "first")
    sign_in_as @member

    delete level_path("6eme"), as: :turbo_stream

    assert_response :success
    assert_equal 0, Orm::Level.count
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("destroy.deleted"))
    assert_select "turbo-stream[action=remove][target=level_6eme]", 1
  end

  test "a level used by a series, a classroom or a course is kept, with the reason (422), and nothing cascades" do
    tle = create_level(name: "Tle", position: 7)
    link_level_series(level: tle, series: create_series(name: "D"))
    create_classroom(level: tle)
    create_course(level: tle)
    sign_in_as @member

    delete level_path("tle"), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: including(tl("destroy.referenced_title"))
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]",
                  text: including(tl("destroy.referenced", name: "Tle", usage: "1 série, 1 classe et 1 cours"))
    assert_select "turbo-stream[action=replace][target=level_tle] tr#level_tle"
    assert_select "turbo-stream[action=remove]", 0
    assert_equal [ 1, 1, 1, 1 ], [ Orm::Level.count, Orm::LevelSeries.count, Orm::Classroom.count, Orm::Course.count ]
  end

  test "without Turbo, a deletion leads back to the list, with a notice or the reason of the refusal" do
    create_level(name: "6ème", position: 1, cycle: "first")
    create_course(level: create_level(name: "Tle", position: 7))
    sign_in_as @member

    delete level_path("6eme")
    assert_redirected_to levels_path
    assert_equal tl("destroy.deleted"), flash[:notice]

    delete level_path("tle")
    assert_redirected_to levels_path
    assert_equal tl("destroy.referenced_alert", name: "Tle", usage: "1 cours"), flash[:alert]
  end
end
