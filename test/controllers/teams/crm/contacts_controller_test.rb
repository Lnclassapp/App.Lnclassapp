require "test_helper"

# CA-09, CA-10 (ADR-XXXX contexte crm, UDR-XXXX bloc « Suivi ») : les contacts d'une école, servis dans le frame school_crm_contacts ;
# ajout en modale, retrait (archivage) après confirmation en GET ; admin et field seuls, 404 pour une autre école.
class Teams::Crm::ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school
    @field = create_team_member(team_role: "field")
    @content = create_team_member(team_role: "content")
    sign_in_as @field
  end

  def turbo = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }

  def contact!(school: @school, **overrides)
    Orm::CrmContact.create!({ school_id: school.id, full_name: "Mme Kouassi", position: "director", phone: "0701020304",
                              note: "Joignable le matin", created_by: @field }.merge(overrides))
  end

  def valid_params(**overrides)
    { contact: { full_name: "Mme Kouassi", position: "director", phone: "0701020304", note: "" }.merge(overrides) }
  end

  def contacts_path = teams_school_contacts_path(@school.public_id)

  test "CA-01: content gets 403 on every contact address" do
    record = contact!
    sign_in_as @content
    school = @school.public_id

    get teams_school_contacts_path(school)
    assert_response :forbidden
    get new_teams_school_contact_path(school)
    assert_response :forbidden
    post teams_school_contacts_path(school), params: valid_params
    assert_response :forbidden
    get archive_teams_school_contact_path(school, record.public_id)
    assert_response :forbidden
    delete teams_school_contact_path(school, record.public_id)
    assert_response :forbidden
    assert_nil record.reload.archived_at
    assert_equal 1, Orm::CrmContact.count
  end

  test "an unknown school is 404 everywhere" do
    record = contact!

    get teams_school_contacts_path("unknown-public")
    assert_response :not_found
    get new_teams_school_contact_path("unknown-public")
    assert_response :not_found
    post teams_school_contacts_path("unknown-public"), params: valid_params
    assert_response :not_found
    get archive_teams_school_contact_path("unknown-public", record.public_id)
    assert_response :not_found
  end

  test "a contact of another school is 404 and stays active" do
    other = contact!(school: create_school)

    get archive_teams_school_contact_path(@school.public_id, other.public_id)
    assert_response :not_found
    delete teams_school_contact_path(@school.public_id, other.public_id), headers: turbo
    assert_response :not_found
    delete teams_school_contact_path(@school.public_id, "unknown")
    assert_response :not_found
    assert_nil other.reload.archived_at
  end

  test "the frame lists the contacts with a call link and a WhatsApp link, and says when there is none" do
    get contacts_path, headers: { "Turbo-Frame" => "school_crm_contacts" }
    assert_select "turbo-frame#school_crm_contacts li", count: 0
    assert_select "a[href=?]", new_teams_school_contact_path(@school.public_id)

    contact!
    contact!(school: create_school, full_name: "Autre école")
    contact!(full_name: "Retirée", archived_at: Time.current)
    get contacts_path, headers: { "Turbo-Frame" => "school_crm_contacts" }

    assert_select "turbo-frame#school_crm_contacts li", count: 1, text: /Mme Kouassi/
    assert_select "li a[href=?]", "tel:0701020304"
    assert_select "li a[href=?][target=_blank][rel~=noopener][aria-label=?]", "https://wa.me/2250701020304", "Écrire sur WhatsApp à Mme Kouassi"
    assert_select "li", text: /Direction/
    assert_select "li", text: /Joignable le matin/
  end

  test "a contact without a phone number shows no link" do
    contact!(phone: nil)

    get contacts_path, headers: { "Turbo-Frame" => "school_crm_contacts" }

    assert_select "li", count: 1
    assert_select "li a[href^='tel:']", count: 0
    assert_select "li a[href*='wa.me']", count: 0
  end

  test "new opens the modal with the fields" do
    get new_teams_school_contact_path(@school.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_select "turbo-frame#modal dialog[open]"
    assert_select "input[name='contact[full_name]'][maxlength='80']"
    assert_select "select[name='contact[position]'] option", minimum: 6
    assert_select "input[name='contact[phone]'][inputmode=tel]"
    assert_select "textarea[name='contact[note]'][maxlength='500']"
  end

  test "CA-09: create adds the contact and answers a Turbo Stream on the contacts block" do
    assert_difference -> { Orm::CrmContact.count }, 1 do
      post contacts_path, headers: turbo, params: valid_params(full_name: " Mme Kouassi ", note: "Directrice")
    end

    assert_response :success
    created = Orm::CrmContact.last
    assert_equal [ @school.id, "Mme Kouassi", "director", "0701020304", "Directrice", @field.id ],
                 [ created.school_id, created.full_name, created.position, created.phone, created.note, created.created_by_id ]
    assert_select "turbo-stream[action=replace][target=school_crm_contacts]"
    assert_select "turbo-stream[action=append][target=toasts]"
  end

  test "create without JavaScript goes back to the school page" do
    post contacts_path, params: valid_params

    assert_redirected_to school_path(@school.public_id)
  end

  test "CA-10: 12345 is refused in 422, with a French message, the input kept and nothing written" do
    assert_no_difference -> { Orm::CrmContact.count } do
      post contacts_path, headers: turbo, params: valid_params(phone: "12345")
    end

    assert_response :unprocessable_entity
    assert_select "dialog[open]"
    assert_select "[id=?]", "contact_phone_error", text: /10 chiffres/
    assert_select "input[name='contact[phone]'][value='12345']"
    assert_select "input[name='contact[full_name]'][value='Mme Kouassi']"
  end

  test "create refuses a blank name and an unknown position" do
    post contacts_path, headers: turbo, params: valid_params(full_name: " ", position: "king")

    assert_response :unprocessable_entity
    assert_select "[id=contact_full_name_error]"
    assert_select "[id=contact_position_error]"
  end

  test "archive asks for confirmation on a GET and removes nothing" do
    record = contact!

    get archive_teams_school_contact_path(@school.public_id, record.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_select "turbo-frame#modal dialog[open]", text: /Mme Kouassi/
    assert_select "form[action=?] input[name=_method][value=delete]", teams_school_contact_path(@school.public_id, record.public_id)
    assert_nil record.reload.archived_at
  end

  test "CA-09: destroy archives the contact, removes it from the block and from the interaction choices, but the journal keeps its name" do
    record = contact!
    Orm::CrmInteraction.create!(school_id: @school.id, author: @field, kind: "call", outcome: "positive", occurred_at: Time.current,
                                contact: record, contact_name: "Mme Kouassi")

    delete teams_school_contact_path(@school.public_id, record.public_id), headers: turbo

    assert_response :success
    assert_not_nil record.reload.archived_at
    assert_select "turbo-stream[action=replace][target=school_crm_contacts]"
    assert_select "turbo-stream[action=append][target=toasts]"
    assert_select "li", text: /Mme Kouassi/, count: 0

    get new_teams_school_interaction_path(@school.public_id)
    assert_select "select[name='interaction[contact_public_id]'] option[value=?]", record.public_id, count: 0
    get teams_school_interactions_path(@school.public_id)
    assert_select "li", text: /Mme Kouassi/
  end

  test "destroy without JavaScript goes back to the school page; removing twice is harmless" do
    record = contact!

    delete teams_school_contact_path(@school.public_id, record.public_id)
    assert_redirected_to school_path(@school.public_id)
    first = record.reload.archived_at
    delete teams_school_contact_path(@school.public_id, record.public_id)
    assert_redirected_to school_path(@school.public_id)
    assert_equal first, record.reload.archived_at
  end
end
