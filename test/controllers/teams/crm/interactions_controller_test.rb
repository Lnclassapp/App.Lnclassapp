require "test_helper"

# CA-11, CA-12 (ADR-XXXX contexte crm, UDR-XXXX bloc « Suivi ») : le journal d'une école, servi dans le frame
# school_crm_journal, 20 échanges par page, en ajout seul. Le dépôt de contacts est celui du Lot B : factice ici.
class Teams::Crm::InteractionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school
    @field = create_team_member(team_role: "field", first_name: "Awa", last_name: "Koné")
    sign_in_as @field
    stub_contacts
  end

  teardown { unstub_contacts }

  def stub_contacts
    @original = Repositories::Crm::ContactRepository.instance_method(:active_for_school)
    Repositories::Crm::ContactRepository.define_method(:active_for_school) { |school_id:| [] }
  end

  def unstub_contacts
    Repositories::Crm::ContactRepository.define_method(:active_for_school, @original)
  end

  # Le dépôt de contacts est encore le squelette du Lot B : find_by_public_id est remplacé par une lecture de la base (restauré après).
  def stub_find_contact(contact)
    original = Repositories::Crm::ContactRepository.instance_method(:find_by_public_id)
    entity = Entities::Crm::Contact.new(public_id: contact.public_id, school_id: contact.school_id, full_name: contact.full_name,
                                        position: contact.position, phone: nil, note: nil, created_by_id: contact.created_by_id, archived_at: nil)
    Repositories::Crm::ContactRepository.define_method(:find_by_public_id) { |public_id:| entity }
    yield
  ensure
    Repositories::Crm::ContactRepository.define_method(:find_by_public_id, original)
  end

  def note!(count = 1, **overrides)
    count.times do |i|
      Orm::CrmInteraction.create!({ school: Orm::School.find(@school.id), author: @field, kind: "call", outcome: "positive",
                                    occurred_at: Time.utc(2026, 10, 1) + i.hours, note: "echange #{i}" }.merge(overrides))
    end
  end

  def journal_path = teams_school_interactions_path(@school.public_id)

  def frame_headers(id = "school_crm_journal") = { "Turbo-Frame" => id }

  def valid_params(**overrides)
    { interaction: { kind: "call", outcome: "positive", occurred_at: "2026-11-04T09:30", note: "Directrice intéressée",
                     next_step: "Envoyer la plaquette", create_follow_up: "0", follow_up_due_on: (Date.current + 3).to_s }.merge(overrides) }
  end

  test "index: an empty journal shows the empty state and the « Noter un échange » button" do
    get journal_path, headers: frame_headers

    assert_response :success
    assert_select "turbo-frame#school_crm_journal" do
      assert_select "a[href=?][data-turbo-frame=modal]", new_teams_school_interaction_path(@school.public_id)
      assert_select "ol li", count: 0
      assert_select "p", text: I18n.t("teams.crm.interactions.index.empty.title")
    end
  end

  test "CA-11: the newest interaction comes first, with its author, type, outcome and escaped note" do
    note!(1, note: "<script>alert(1)</script>", occurred_at: Time.utc(2026, 10, 3), source: "dictation", next_step: "Rappeler")
    note!(1, note: "plus ancien", occurred_at: Time.utc(2026, 10, 1), outcome: "negative")

    get journal_path, headers: frame_headers

    assert_select "ol[role=list] > li", count: 2
    assert_select "ol > li:first-child" do |first|
      assert_includes first.text, "Awa Koné"
      assert_includes first.text, "Appel"
      assert_includes first.text, "Positif"
      assert_includes first.text, "Dicté"
      assert_includes first.text, "Rappeler"
      assert_includes first.to_html, "&lt;script&gt;"
      assert_select "time[datetime]"
    end
    assert_select "script", text: /alert/, count: 0
    assert_select "ol > li:last-child", text: /Négatif/
  end

  test "CA-12: no edit, update or destroy control or route exists for an interaction" do
    note!

    get journal_path, headers: frame_headers

    assert_select "form[method=post]", count: 0
    assert_select "a[href*=edit], button[type=submit]", count: 0
    %i[edit_teams_school_interaction_path teams_school_interaction_path].each { assert_not respond_to?(it) }
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/teams/schools/#{@school.public_id}/interactions/x", method: :patch) }
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/teams/schools/#{@school.public_id}/interactions/x", method: :delete) }
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/teams/schools/#{@school.public_id}/interactions/x/edit") }
  end

  test "pagination: 20 per page, then a link loads the older ones in their own frame" do
    note!(25)

    get journal_path, headers: frame_headers
    assert_select "ol > li", count: 20
    assert_select "a[href=?]", teams_school_interactions_path(@school.public_id, page: 2), text: I18n.t("teams.crm.interactions.index.older")

    get teams_school_interactions_path(@school.public_id, page: 2), headers: frame_headers("school_crm_journal_page_2")
    assert_select "turbo-frame#school_crm_journal_page_2 li", count: 5
    assert_select "a", text: I18n.t("teams.crm.interactions.index.older"), count: 0
  end

  test "an exact multiple of 20 shows no « older » link" do
    note!(20)

    get journal_path, headers: frame_headers

    assert_select "ol > li", count: 20
    assert_select "a", text: I18n.t("teams.crm.interactions.index.older"), count: 0
  end

  test "new: the modal form offers the types, results, and the follow-up date defaulting to 3 days" do
    get new_teams_school_interaction_path(@school.public_id), headers: frame_headers("modal")

    assert_response :success
    assert_select "turbo-frame#modal" do
      assert_select "input[type=radio][name='interaction[kind]']", count: 5
      assert_select "input[type=radio][name='interaction[outcome]']", count: 3
      assert_select "textarea[name='interaction[note]'][maxlength='2000']"
      assert_select "input[type=checkbox][name='interaction[create_follow_up]']"
      assert_select "input[name='interaction[follow_up_due_on]'][value=?]", (Date.current + 3).to_s
    end
  end

  test "CA-11: create records the interaction and the follow-up, answers in turbo stream" do
    assert_difference [ "Orm::CrmInteraction.count", "Orm::CrmFollowUp.count" ], 1 do
      post teams_school_interactions_path(@school.public_id),
           params: valid_params(create_follow_up: "1", follow_up_due_on: (Date.current + 3).to_s), as: :turbo_stream
    end

    assert_response :success
    assert_includes response.body, 'target="school_crm_journal"'
    assert_includes response.body, 'target="school_crm_follow_ups"'
    assert_includes response.body, 'target="modal"'
    created = Orm::CrmInteraction.last
    assert_equal [ @field.id, @school.id, "call", "positive", "Directrice intéressée", "manual" ],
                 [ created.author_id, created.school_id, created.kind, created.outcome, created.note, created.source ]
    follow_up = Orm::CrmFollowUp.last
    assert_equal [ @field.id, Date.current + 3, "Envoyer la plaquette", "open" ],
                 [ follow_up.assignee_id, follow_up.due_on, follow_up.reason, follow_up.status ]
  end

  test "create without the follow-up box writes only the interaction, and a plain request is redirected to the school" do
    assert_difference "Orm::CrmInteraction.count", 1 do
      assert_no_difference "Orm::CrmFollowUp.count" do
        post teams_school_interactions_path(@school.public_id), params: valid_params
      end
    end

    assert_redirected_to school_path(@school.public_id)
  end

  test "create keeps a free-text interlocutor and the dictation source" do
    post teams_school_interactions_path(@school.public_id),
         params: valid_params(contact_name: "Le censeur", source: "dictation"), as: :turbo_stream

    assert_equal [ "Le censeur", "dictation" ], Orm::CrmInteraction.last.then { [ it.contact_name, it.source ] }
  end

  test "create with a chosen contact links the interaction to it" do
    contact = Orm::CrmContact.create!(school_id: @school.id, full_name: "Mme Kouassi", position: "director", created_by: @field)

    stub_find_contact(contact) do
      post teams_school_interactions_path(@school.public_id),
           params: valid_params(contact_public_id: contact.public_id), as: :turbo_stream
    end

    created = Orm::CrmInteraction.last
    assert_equal [ contact.id, "Mme Kouassi" ], [ created.contact_id, created.contact_name ]
  end

  test "create with an invalid follow-up date or no outcome re-renders the modal in 422 and writes nothing" do
    assert_no_difference [ "Orm::CrmInteraction.count", "Orm::CrmFollowUp.count" ] do
      post teams_school_interactions_path(@school.public_id),
           params: valid_params(outcome: "", create_follow_up: "1", follow_up_due_on: (Date.current - 1).to_s), as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal [id$=_error]"
  end

  test "an unknown school is a 404" do
    get teams_school_interactions_path("unknown-public"), headers: frame_headers

    assert_response :not_found
  end

  test "CA-02: a content member and a teacher receive 403 on every address" do
    [ create_team_member(team_role: "content"), create_teacher ].each do |user|
      sign_in_as user
      get journal_path
      assert_response :forbidden
      get new_teams_school_interaction_path(@school.public_id)
      assert_response :forbidden
      post teams_school_interactions_path(@school.public_id), params: valid_params
      assert_response :forbidden
      sign_out
    end
    assert_equal 0, Orm::CrmInteraction.count
  end
end
