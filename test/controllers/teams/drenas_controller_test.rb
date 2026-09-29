require "test_helper"

# SC-01, ADR-0036, ADR-0066, UDR-0006: the team manages the DRENA — their frozen slug, prefixed drena-, being the target
# of the school imports; creation and edition in the modal frame, writes answered in Turbo Stream, an HTML fallback.
class Teams::DrenasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
  end

  def row(drena) = "tr#drena_#{drena.public_id}"

  test "a teacher, a student and a school admin receive 403 on every action" do
    drena = create_drena

    [ create_teacher, create_student, create_user(role: "school_admin") ].each do |user|
      sign_in_as user

      get drenas_path
      assert_response :forbidden
      get new_drena_path
      assert_response :forbidden
      post drenas_path, params: { drena: { name: "Abidjan 1" } }
      assert_response :forbidden
      get edit_drena_path(drena)
      assert_response :forbidden
      patch drena_path(drena), params: { drena: { name: "Abidjan 1" } }
      assert_response :forbidden
      delete drena_path(drena)
      assert_response :forbidden
      sign_out
    end
    assert_equal [ drena.name ], Orm::Drena.where(name: [ drena.name, "Abidjan 1" ]).pluck(:name)
  end

  test "the list shows each DRENA by name, its slug for the imports, and its counts" do
    yamoussoukro = create_drena(name: "Yamoussoukro")
    abidjan = create_drena(name: "Abidjan 1")
    create_classroom(school: create_school(drena: abidjan))
    sign_in_as @member

    get drenas_path

    assert_response :success
    assert_select "h1", "DRENA"
    assert_select "a[data-turbo-frame=modal][href='#{new_drena_path}']", text: "Nouvelle DRENA"
    assert_select "#drenas tr", 2
    assert_select "#drenas tr:first-child#drena_#{abidjan.public_id}" do
      assert_select "td", text: "Abidjan 1"
      assert_select "code", "drena-abidjan-1"
      assert_select "a[data-turbo-frame=modal][href='#{edit_drena_path(abidjan)}']"
      assert_select "dialog#delete-drena-#{abidjan.public_id} form[action='#{drena_path(abidjan)}'] input[name=_method][value=delete]",
                    count: 1, visible: :all
    end
    assert_select "#{row(abidjan)} td.tabular-nums", text: "1", count: 2
    assert_select "#{row(yamoussoukro)} code", "drena-yamoussoukro"
    assert_select "th", text: /Slug\s+\(à utiliser dans les fichiers d'import\)/
    assert_select "#drenas_empty:empty"
  end

  test "with no DRENA, the list is empty and says what to do" do
    sign_in_as @member

    get drenas_path

    assert_select "#drenas tr", 0
    assert_select "#drenas_empty", text: /Aucune DRENA pour l'instant/
  end

  test "the creation form opens in the modal frame" do
    sign_in_as @member

    get new_drena_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal", 1
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#drena-modal[aria-labelledby]"
    assert_select "form#drena-form[action='#{drenas_path}'][method=post] input[name='drena[name]'][maxlength='80'][required]"
    assert_select "button[type=submit][form=drena-form]", "Créer la DRENA"
  end

  test "without a frame, the creation form is the same modal, opened on the shell" do
    sign_in_as @member

    get new_drena_path

    assert_response :success
    assert_select "main#main turbo-frame#modal dialog#drena-modal"
  end

  test "a valid creation answers in Turbo Stream: toast, list refreshed, modal closed; the change is audited" do
    create_drena(name: "Bouaké")
    sign_in_as @member

    post drenas_path, params: { drena: { name: "  Abidjan   1 " } }, as: :turbo_stream

    drena = Orm::Drena.find_by!(name: "Abidjan 1")
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal "drena-abidjan-1", drena.slug
    assert_select "turbo-stream[action=append][target=toasts]", text: /DRENA « Abidjan 1 » créée/
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=update][target=drenas_empty]"
    assert_select "turbo-stream[action=update][target=drenas] template" do
      assert_select "tr", 2
      assert_select "tr:first-child#drena_#{drena.public_id} code", "drena-abidjan-1"
    end
    event = Orm::AuditEvent.sole
    assert_equal [ "school.changed", @member.id, "Drena", drena.id ], [ event.action, event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "change" => "drena.created", "name" => "Abidjan 1" }, event.metadata)
  end

  test "a taken name reopens the modal in 422 with the error on the name, and nothing is created" do
    create_drena(name: "Abidjan 1")
    sign_in_as @member

    assert_no_difference -> { Orm::Drena.count } do
      post drenas_path, params: { drena: { name: "Abidjan 1" } }, headers: { "Turbo-Frame" => "modal" }
    end

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog#drena-modal"
    assert_select "input[name='drena[name]'][value='Abidjan 1'][aria-invalid=true]"
    assert_select "#drena_name_error", "Une DRENA porte déjà ce nom."
  end

  test "a blank name is refused in the modal" do
    sign_in_as @member

    post drenas_path, params: { drena: { name: "  " } }, headers: { "Turbo-Frame" => "modal" }

    assert_response :unprocessable_entity
    assert_select "#drena_name_error", "Indiquez le nom de la DRENA."
    assert_equal 0, Orm::Drena.count
  end

  # DR-08 (ADR-0066): the slug would be a bare « drena ».
  test "a name without any latin letter or digit reopens the modal in 422 with the error on the name, and nothing is created" do
    sign_in_as @member

    assert_no_difference -> { Orm::Drena.count } do
      post drenas_path, params: { drena: { name: "???" } }, headers: { "Turbo-Frame" => "modal" }
    end

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog#drena-modal"
    assert_select "input[name='drena[name]'][value='???'][aria-invalid=true]"
    assert_select "#drena_name_error", "Le nom doit contenir au moins une lettre ou un chiffre latin."
  end

  test "a request without the drena parameters is a bad request" do
    sign_in_as @member

    post drenas_path, params: { name: "Abidjan 1" }

    assert_response :bad_request
  end

  test "without Turbo, a creation leads back to the list with a notice" do
    sign_in_as @member

    post drenas_path, params: { drena: { name: "Abidjan 1" } }

    assert_redirected_to drenas_path
    assert_equal "DRENA « Abidjan 1 » créée.", flash[:notice]
  end

  test "the edition form opens in the modal frame with the current name, and recalls the frozen slug" do
    drena = create_drena(name: "Abidjan 1")
    sign_in_as @member

    get edit_drena_path(drena), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog#drena-modal"
    assert_select "form#drena-form[action='#{drena_path(drena)}'] input[name=_method][value=patch]"
    assert_select "input[name='drena[name]'][value='Abidjan 1']"
    assert_select "#drena_name_hint code", "drena-abidjan-1"
    assert_select "button[type=submit][form=drena-form]", "Enregistrer"
  end

  test "an unknown DRENA, or its numeric id, is not found" do
    drena = create_drena
    sign_in_as @member

    get edit_drena_path("inconnu")
    assert_response :not_found
    get edit_drena_path(drena.id)
    assert_response :not_found
    patch drena_path("inconnu"), params: { drena: { name: "Abidjan 1" } }
    assert_response :not_found
    delete drena_path(drena.id), as: :turbo_stream
    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: /Page introuvable/
  end

  test "a renaming keeps the slug and answers in Turbo Stream" do
    drena = create_drena(name: "Abidjan 1")
    sign_in_as @member

    patch drena_path(drena), params: { drena: { name: "Abidjan 1 Plateau" } }, as: :turbo_stream

    assert_response :success
    assert_equal [ "Abidjan 1 Plateau", "drena-abidjan-1" ], [ drena.reload.name, drena.slug ]
    assert_select "turbo-stream[action=append][target=toasts]", text: /DRENA « Abidjan 1 Plateau » modifiée/
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=update][target=drenas] template #{row(drena)}", text: /Abidjan 1 Plateau/
    assert_equal({ "change" => "drena.updated", "name" => "Abidjan 1 Plateau", "previous_name" => "Abidjan 1" },
                 Orm::AuditEvent.sole.metadata)
  end

  test "renaming to a taken name reopens the modal in 422, the DRENA unchanged" do
    drena = create_drena(name: "Abidjan 1")
    create_drena(name: "Abidjan 2")
    sign_in_as @member

    patch drena_path(drena), params: { drena: { name: "Abidjan 2" } }, headers: { "Turbo-Frame" => "modal" }

    assert_response :unprocessable_entity
    assert_select "form#drena-form[action='#{drena_path(drena)}']"
    assert_select "#drena_name_error", "Une DRENA porte déjà ce nom."
    assert_equal "Abidjan 1", drena.reload.name
  end

  test "without Turbo, a renaming leads back to the list with a notice" do
    drena = create_drena(name: "Abidjan 1")
    sign_in_as @member

    patch drena_path(drena), params: { drena: { name: "Abidjan 1 Plateau" } }

    assert_redirected_to drenas_path
    assert_equal "DRENA « Abidjan 1 Plateau » modifiée.", flash[:notice]
  end

  test "deleting a DRENA without school removes its row in Turbo Stream" do
    drena = create_drena(name: "Abidjan 1")
    create_drena(name: "Abidjan 2")
    sign_in_as @member

    delete drena_path(drena), as: :turbo_stream

    assert_response :success
    assert_not Orm::Drena.exists?(drena.id)
    assert_select "turbo-stream[action=append][target=toasts]", text: /DRENA « Abidjan 1 » supprimée/
    assert_select "turbo-stream[action=remove][target=drena_#{drena.public_id}]"
    assert_select "turbo-stream[target=drenas_empty]", 0
    assert_equal({ "change" => "drena.deleted", "name" => "Abidjan 1" }, Orm::AuditEvent.sole.metadata)
  end

  test "deleting the last DRENA brings the empty state back" do
    drena = create_drena(name: "Abidjan 1")
    sign_in_as @member

    delete drena_path(drena), as: :turbo_stream

    assert_select "turbo-stream[action=remove][target=drena_#{drena.public_id}]"
    assert_select "turbo-stream[action=update][target=drenas_empty] template", text: /Aucune DRENA pour l'instant/
  end

  test "deleting a DRENA that has schools is refused with the reason, in 422, and nothing is deleted" do
    drena = create_drena(name: "Abidjan 1")
    school = create_school(drena:)
    create_school(drena:)
    create_classroom(school:)
    sign_in_as @member

    assert_no_difference [ "Orm::Drena.count", "Orm::School.count", "Orm::Classroom.count" ] do
      delete drena_path(drena), as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]",
                  text: /La DRENA « Abidjan 1 » a 2 établissements : elle ne peut pas être supprimée/
    assert_select "turbo-stream[action=replace][target=drena_#{drena.public_id}] template #{row(drena)}"
    assert_equal 0, Orm::AuditEvent.count
  end

  test "without Turbo, a deletion leads back to the list, with a notice or the refusal" do
    kept = create_drena(name: "Abidjan 1")
    create_school(drena: kept)
    removed = create_drena(name: "Abidjan 2")
    sign_in_as @member

    delete drena_path(removed)
    assert_redirected_to drenas_path
    assert_equal "DRENA « Abidjan 2 » supprimée.", flash[:notice]

    delete drena_path(kept)
    assert_redirected_to drenas_path
    assert_equal "La DRENA « Abidjan 1 » a 1 établissement : elle ne peut pas être supprimée.", flash[:alert]
    assert Orm::Drena.exists?(kept.id)
  end
end
