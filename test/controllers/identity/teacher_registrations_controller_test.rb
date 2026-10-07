require "test_helper"

# IE-01 to IE-13, IE-17, IE-19 server side (ADR-0082, UDR-0078): one sign-up page in three sections (school, you, secret
# code), no school code. The standard way chooses the DRENA then the school; an invite link /i/<token> arrives with the
# school already chosen. The teacher is attached at once and the way in is recorded.
class Identity::TeacherRegistrationsControllerTest < ActionDispatch::IntegrationTest
  ERRORS = "activemodel.errors.models.dtos/identity/teacher_registration_input.attributes".freeze
  PAGE = "identity.teacher_registrations.new".freeze
  FORM = "identity.teacher_registrations.form".freeze

  setup do
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Moderne de Cocody", school_code: "k7m4qz")
    @material = create_material(name: "SVT", shortname: "SVT")
  end

  def registration_params(**overrides)
    { last_name: "KOUASSI", first_name: "Aya Marie", gender: "female", contact: "05 01 02 03 04", pin: "4821", pin_confirmation: "4821",
      drena_public_id: @drena.public_id, school_public_id: @school.public_id, material_slug: @material.slug, **overrides }
  end

  def referral_token_of(teacher) = Orm::TeacherProfile.find_by!(user: teacher).referral_token
  def new_teacher = Orm::User.find_by!(contact: "0501020304")
  def joined_via = Orm::TeacherProfile.find_by!(user: new_teacher).joined_via

  def assert_refused(attribute, message)
    assert_response :unprocessable_entity
    assert_select "#teacher_registration_#{attribute}_error", text: message
    assert_not Orm::User.exists?(contact: "0501020304")
  end

  test "IE-02, IE-03: three sections in order, the DRENA then the list, Nom then Prénom(s) — never a school code" do
    get new_teacher_registration_path

    assert_response :success
    assert_select "h2", text: I18n.t("#{PAGE}.title")
    assert_select "form#teacher-signup-drena[action='#{new_teacher_registration_path}'][method=get]"
    assert_select "form#teacher-registration-form[action='#{teacher_registrations_path}']" \
                  "[data-controller='school--drena-schools identity--phone-digits identity--pin-match']" do
      assert_equal [ "Établissement", "Vous", "Code secret" ], css_select("fieldset > legend.uppercase").map { it.text.strip }
      assert_select "select[name='teacher_registration[drena_public_id]'][form=teacher-signup-drena] option[value='#{@drena.public_id}']"
      assert_select "turbo-frame#schools select[name='teacher_registration[school_public_id]'][disabled]"
      assert_select "select[name='teacher_registration[material_slug]'] option[value='#{@material.slug}']", text: "SVT"
      assert_select "input[name='teacher_registration[last_name]'][required][maxlength='50'][autocomplete=family-name]" \
                    "[placeholder='Ex. : KOUASSI']"
      assert_select "input[name='teacher_registration[first_name]'][required][maxlength='80'][autocomplete=given-name]" \
                    "[placeholder='Ex. : Aya Marie']"
      assert_select "input[name='teacher_registration[full_name]'], details, #full_name_preview", 0
      assert_select "input[type=radio][name='teacher_registration[gender]']", count: 2
      assert_select "input[type=tel][name='teacher_registration[contact]'][maxlength='20'][inputmode=numeric]:not([pattern])"
      assert_select "input[type=password][name='teacher_registration[pin]'][inputmode=numeric][maxlength='4']"
      assert_select "input[type=password][name='teacher_registration[pin_confirmation]'][data-identity--pin-match-target=confirmation]"
      assert_select "p#pin_match_status[hidden][aria-live=polite]"
      assert_select "input[name='teacher_registration[invite_token]']", 0
    end
    assert_select "[name*=school_code], [name*=national_code], [name*=role]", 0
    assert_select "#school-preview, #invite-link-invalid", 0
    assert_no_match(/Code d'établissement/, response.body)
    assert_select "a[href='#{new_session_path}']"
  end

  test "without JavaScript, the DRENA chosen comes back in GET and lists its active schools" do
    create_school(drena: @drena, name: "Lycée fermé", status: "inactive")

    get new_teacher_registration_path, params: { teacher_registration: { drena_public_id: @drena.public_id } }

    assert_response :success
    assert_select "select[name='teacher_registration[drena_public_id]'] option[selected][value='#{@drena.public_id}']"
    assert_select "turbo-frame#schools select[name='teacher_registration[school_public_id]']:not([disabled]) " \
                  "option[value='#{@school.public_id}']", text: "Lycée Moderne de Cocody"
    assert_no_match(/Lycée fermé/, response.body)
  end

  test "IE-01: a standard sign-up attaches the teacher at once, way « standard », no join request, signed in" do
    post teacher_registrations_path, params: { teacher_registration: registration_params }

    assert_redirected_to teacher_classrooms_path
    assert_response :see_other
    assert_equal I18n.t("identity.teacher_registrations.create.welcome"), flash[:notice]
    assert_equal [ "teacher", nil, "KOUASSI", "Aya Marie", "female" ],
                 [ new_teacher.role, new_teacher.team_role, new_teacher.last_name, new_teacher.first_name, new_teacher.gender ]
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher: new_teacher).pluck(:school_id, :primary)
    assert_equal "standard", joined_via
    assert_equal 0, Orm::SchoolJoinRequest.count
    assert Orm::User.authenticate_by(contact: "0501020304", pin: "4821")
    assert cookies[:session_token].present?
  end

  test "IE-03: the name and the first names are saved as typed, spaces reduced, case kept" do
    post teacher_registrations_path,
         params: { teacher_registration: registration_params(last_name: " N'GUESSAN ", first_name: "Konan  Jean-Baptiste") }

    assert_redirected_to teacher_classrooms_path
    assert_equal [ "N'GUESSAN", "Konan Jean-Baptiste" ], [ new_teacher.last_name, new_teacher.first_name ]
  end

  test "IE-05: missing first names are refused in 422 under « Prénom(s) », the name kept, no account" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(first_name: "  ") }

    assert_refused :first_name, I18n.t("#{ERRORS}.first_name.blank")
    assert_select "input[name='teacher_registration[last_name]'][value='KOUASSI']"
    assert_select "#teacher_registration_last_name_error", 0
  end

  test "ADR-0037: a missing name or an invalid first name is refused under its own field, the entry kept" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(last_name: "", first_name: "Aya 2") }

    assert_refused :last_name, I18n.t("#{ERRORS}.last_name.blank")
    assert_select "#teacher_registration_first_name_error", text: I18n.t("#{ERRORS}.first_name.invalid")
    assert_select "input[name='teacher_registration[first_name]'][value='Aya 2'][aria-invalid=true]"
  end

  test "IE-17, IE-19 without JavaScript: different codes are refused in 422; « +225 07 01 02 03 04 » is saved cleaned" do
    post teacher_registrations_path,
         params: { teacher_registration: registration_params(contact: "+225 07 01 02 03 04", pin_confirmation: "1357") }

    assert_response :unprocessable_entity
    assert_select "#teacher_registration_pin_confirmation_error", text: I18n.t("#{ERRORS}.pin_confirmation.confirmation")
    assert_select "input[name='teacher_registration[contact]'][value='+225 07 01 02 03 04']"
    assert_select "input[name='teacher_registration[last_name]'][value='KOUASSI']"
    assert_select "input[name='teacher_registration[first_name]'][value='Aya Marie']"
    assert_select "input[name='teacher_registration[pin]'][value]", count: 0
    assert_select "turbo-frame#schools option[selected][value='#{@school.public_id}']"

    post teacher_registrations_path, params: { teacher_registration: registration_params(contact: "+225 07 01 02 03 04") }

    assert_redirected_to teacher_classrooms_path
    assert Orm::User.exists?(contact: "0701020304", role: "teacher")
  end

  test "IE-11: a draft, inactive school or one of another DRENA is refused in 422 with the same message, no account" do
    others = [ create_school(drena: @drena, status: "inactive"), create_school(drena: @drena, status: "draft"),
               create_school(drena: create_drena) ]

    others.each do |school|
      post teacher_registrations_path, params: { teacher_registration: registration_params(school_public_id: school.public_id) }

      assert_refused :school_public_id, I18n.t("#{ERRORS}.school_public_id.inclusion")
      assert_select "select[name='teacher_registration[drena_public_id]'] option[selected][value='#{@drena.public_id}']"
    end
  end

  test "IE-11: after a 422 on a school no longer listed, « Choisissez votre établissement » stays, selected, never a school" do
    create_school(drena: @drena, name: "Lycée Alpha")
    closed = create_school(drena: @drena, status: "inactive")

    post teacher_registrations_path, params: { teacher_registration: registration_params(school_public_id: closed.public_id) }

    assert_refused :school_public_id, I18n.t("#{ERRORS}.school_public_id.inclusion")
    assert_select "select[name='teacher_registration[school_public_id]']" do
      assert_select "option:first-child[value=''][selected]", text: I18n.t("school.drena_schools.index.prompt")
      assert_select "option[selected]", 1
      assert_select "option[value='#{@school.public_id}']", text: "Lycée Moderne de Cocody"
    end
  end

  test "IE-11: a school still listed comes back selected after a 422, the prompt kept unselected" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(pin_confirmation: "1357") }

    assert_response :unprocessable_entity
    assert_select "select[name='teacher_registration[school_public_id]']" do
      assert_select "option[selected]", 1
      assert_select "option[selected][value='#{@school.public_id}']"
    end
  end

  test "IE-11: no DRENA chosen: each field says so in 422" do
    post teacher_registrations_path,
         params: { teacher_registration: registration_params(drena_public_id: "", school_public_id: "") }

    assert_refused :drena_public_id, I18n.t("#{ERRORS}.drena_public_id.blank")
    assert_select "#teacher_registration_school_public_id_error", text: I18n.t("#{ERRORS}.school_public_id.blank")
  end

  test "IE-06: the colleague's link shows the school and its DRENA, carries the token hidden, and keeps a way out" do
    token = referral_token_of(create_teacher(school: @school))

    get teacher_invite_link_path(token)

    assert_response :success
    assert_select "#school-preview", text: /Lycée Moderne de Cocody/
    assert_select "#school-preview", text: /Abidjan 1/
    assert_select "form#teacher-registration-form input[type=hidden][name='teacher_registration[invite_token]'][value='#{token}']"
    assert_select "a#other-school[href='#{new_teacher_registration_path}']", text: I18n.t("#{FORM}.other_school")
    assert_select "select[name='teacher_registration[drena_public_id]'], turbo-frame#schools", 0
    assert_select "select[name='teacher_registration[material_slug]']"
    assert_select "#invite-link-invalid", 0
    assert_no_match(/k7m4qz|K7M-4QZ/i, response.body)
    assert_not_includes response.body, @school.public_id
    assert_empty session.to_h.except("session_id", "_csrf_token", "csp_nonce"), "le jeton ne va pas en session"
  end

  test "IE-06: signing up by the colleague's link attaches to the school of the link, way « colleague », referral counted" do
    referrer = create_teacher(school: @school)

    post teacher_registrations_path,
         params: { teacher_registration: registration_params(invite_token: referral_token_of(referrer), drena_public_id: nil,
                                                             school_public_id: nil) }

    assert_redirected_to teacher_classrooms_path
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher: new_teacher).pluck(:school_id, :primary)
    assert_equal "colleague", joined_via
    assert_equal [ [ referrer.id, @school.id, "link" ] ],
                 Orm::Referral.where(referee: new_teacher).pluck(:referrer_id, :school_id, :source)
  end

  test "IE-07, IE-08: the direction's and the team's links give their way, without referral" do
    { direction_invite_token: "direction", team_invite_token: "team" }.each_with_index do |(column, channel), index|
      contact = "05010203#{10 + index}"

      post teacher_registrations_path,
           params: { teacher_registration: registration_params(invite_token: @school.public_send(column), contact:,
                                                               drena_public_id: nil, school_public_id: nil) }

      assert_redirected_to teacher_classrooms_path
      teacher = Orm::User.find_by!(contact:)
      assert_equal channel, Orm::TeacherProfile.find_by!(user: teacher).joined_via
      assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher:).pluck(:school_id)
      sign_out
    end
    assert_equal 0, Orm::Referral.count
  end

  test "IE-09: an unknown link, one of an inactive school or of a withdrawn colleague opens the standard page in 200" do
    closed = create_school(drena: @drena, name: "Lycée fermé", status: "inactive")
    withdrawn = create_teacher(school: nil)

    [ "cccccccccccc", "not-a-token", closed.team_invite_token, referral_token_of(withdrawn) ].each do |token|
      get teacher_invite_link_path(token)

      assert_response :success, token
      assert_select "#invite-link-invalid[role=alert]", text: I18n.t("#{PAGE}.invite_invalid")
      assert_select "select[name='teacher_registration[drena_public_id]']"
      assert_select "input[name='teacher_registration[invite_token]'], #school-preview", 0
      assert_no_match(/Lycée fermé/, response.body)
    end
  end

  test "IE-09: a link that became invalid before the submit falls back to the school chosen, way « standard »" do
    referrer = create_teacher(school: create_school(drena: @drena, status: "inactive"))

    post teacher_registrations_path,
         params: { teacher_registration: registration_params(invite_token: referral_token_of(referrer)) }

    assert_redirected_to teacher_classrooms_path
    assert_equal "standard", joined_via
    assert_equal 0, Orm::Referral.count
  end

  test "an error after a valid link keeps the banner and the token, never the PINs" do
    token = @school.team_invite_token

    post teacher_registrations_path,
         params: { teacher_registration: registration_params(invite_token: token, pin_confirmation: "1357") }

    assert_refused :pin_confirmation, I18n.t("#{ERRORS}.pin_confirmation.confirmation")
    assert_select "#school-preview", text: /Lycée Moderne de Cocody/
    assert_select "input[type=hidden][name='teacher_registration[invite_token]'][value='#{token}']"
    assert_select "select[name='teacher_registration[drena_public_id]']", 0
    assert_select "input[name='teacher_registration[pin]'][value]", count: 0
  end

  test "IE-12: a number already used by a teacher, a student or a direction is refused in 422, the role never revealed" do
    { "teacher" => :create_teacher, "student" => :create_student, "school_admin" => :create_school_admin }
      .each_with_index do |(role, factory), index|
        existing = public_send(factory, contact: "0501020304")
        count = Orm::User.count

        post teacher_registrations_path, params: { teacher_registration: registration_params }

        assert_response :unprocessable_entity, role
        message = css_select("#teacher_registration_contact_error").text.strip
        assert_equal I18n.t("#{ERRORS}.contact.taken"), message, role
        assert_no_match(/enseignant|élève|direction/i, message, role)
        assert_equal [ count, role ], [ Orm::User.count, Orm::User.find_by!(contact: "0501020304").role ], role
        existing.update_columns(contact: "070000000#{index}")
      end
  end

  test "IE-23: each sign-up leaves one audit line school.changed / teacher_joined with the school and the way" do
    post teacher_registrations_path, params: { teacher_registration: registration_params }

    assert_redirected_to teacher_classrooms_path
    event = Orm::AuditEvent.sole
    assert_equal [ "school.changed", new_teacher.id, "School", @school.id, { "change" => "teacher_joined", "via" => "standard" } ],
                 [ event.action, event.actor_id, event.subject_type, event.subject_id, event.metadata ]
  end

  test "IE-10: from a colleague's link, « Ce n'est pas votre établissement ? » then the sign-up: way « standard », no referral" do
    get teacher_invite_link_path(referral_token_of(create_teacher(school: @school)))
    other_school = css_select("a#other-school").first["href"]

    get other_school

    assert_response :success
    assert_select "input[name='teacher_registration[invite_token]']", 0
    post teacher_registrations_path, params: { teacher_registration: registration_params }

    assert_redirected_to teacher_classrooms_path
    assert_equal "standard", joined_via
    assert_equal 0, Orm::Referral.count
    assert_equal "standard", Orm::AuditEvent.sole.metadata["via"]
  end

  test "a way forged in the POST is ignored: standard without a token, colleague with a valid colleague's token" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(joined_via: "team") }

    assert_redirected_to teacher_classrooms_path
    assert_equal "standard", joined_via
    sign_out
    referrer = create_teacher(school: @school)

    post teacher_registrations_path,
         params: { teacher_registration: registration_params(contact: "05 01 02 03 99", joined_via: "direction",
                                                             invite_token: referral_token_of(referrer)) }

    assert_redirected_to teacher_classrooms_path
    assert_equal "colleague", Orm::TeacherProfile.find_by!(user: Orm::User.find_by!(contact: "0501020399")).joined_via
  end

  test "IE-02: the old code link /e/K7M-4QZ answers 404" do
    get "/e/K7M-4QZ"

    assert_response :not_found
    assert_no_match(/Lycée Moderne de Cocody/, response.body)
  end

  test "IE-13: a signed-in person who opens the page or a link is sent home; a POST is refused" do
    sign_in_as create_teacher

    get new_teacher_registration_path
    assert_redirected_to teacher_home_path

    get teacher_invite_link_path(@school.team_invite_token)
    assert_redirected_to teacher_home_path

    post teacher_registrations_path, params: { teacher_registration: registration_params }
    assert_response :forbidden
    assert_not Orm::User.exists?(contact: "0501020304")
  end

  test "a role added by hand is ignored, the account is a teacher" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(role: "team", team_role: "admin") }

    assert_redirected_to teacher_classrooms_path
    assert_equal [ "teacher", nil ], Orm::User.where(contact: "0501020304").pick(:role, :team_role)
  end

  test "an unknown subject is refused in 422" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(material_slug: "latin") }

    assert_refused :material_slug, I18n.t("#{ERRORS}.material_slug.inclusion")
  end

  test "a sixth attempt in a minute receives 429 in the form" do
    6.times { post teacher_registrations_path, params: { teacher_registration: registration_params(pin_confirmation: "1357") } }

    assert_response :too_many_requests
    assert_select "[role=alert]", text: I18n.t("errors.codes.rate_limited")
  end

  test "UDR-0078 §3.6: the eleventh link opened in a minute receives 429, without the school; the form keeps its own count" do
    10.times { |index| get teacher_invite_link_path(index.even? ? @school.team_invite_token : "cccccccccccc") }

    get teacher_invite_link_path(@school.team_invite_token)

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /#{Regexp.escape(I18n.t('errors.codes.rate_limited'))}/
    assert_not_includes response.body, "Lycée Moderne de Cocody"
    assert_select "form#teacher-registration-form", 0

    get new_teacher_registration_path
    assert_response :success
  end
end
