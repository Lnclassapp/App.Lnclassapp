require "test_helper"

# IE-01 to IE-13, IE-17, IE-19 and CA-J1 to CA-J4 server side (ADR-0083, UDR-0079, UDR « écrans enseignant sans répétition » §3.9):
# one sign-up form cut in three steps (number, secret code typed once, profile) by signup_steps_controller, no school code
# (chantier connexion-numero-d-abord, UDR-0189 §3.5). The standard way chooses the DRENA then the school; an invite link /i/<token> arrives with the
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
    { last_name: "KOUASSI", first_name: "Aya Marie", gender: "female", contact: "05 01 02 03 04", pin: "4821",
      school_public_id: @school.public_id, material_slug: @material.slug, **overrides }
  end

  def referral_token_of(teacher) = Orm::TeacherProfile.find_by!(user: teacher).referral_token
  # ADR-0094 §11 (MET-8): the colleague's link for his school is the token of his attachment.
  def school_token_of(teacher) = Orm::TeacherSchool.find_by!(teacher:).invite_token
  def new_teacher = Orm::User.find_by!(contact: "0501020304")
  def joined_via = Orm::TeacherProfile.find_by!(user: new_teacher).joined_via

  def assert_refused(attribute, message)
    assert_response :unprocessable_entity
    assert_select "#teacher_registration_#{attribute}_error", text: message
    assert_not Orm::User.exists?(contact: "0501020304")
  end

  # Chantier entree-eleve-unifiee, D1 (PRD CA-12, UDR-0176 §3.7).
  test "CA-12 : l'inscription publique s'ouvre sur « Êtes-vous bien enseignant(e) ? », sans formulaire" do
    get new_teacher_registration_path

    assert_response :success
    assert_select "h1", text: "Êtes-vous bien enseignant(e) ?"
    assert_select "form#teacher-registration-form", 0
    assert_select "a#teacher-signup-confirm-yes[href=?]", new_teacher_registration_path(confirmed: 1), text: "Oui, je suis enseignant(e)"
    assert_select "a#teacher-signup-confirm-no[href=?]", new_student_entry_path, text: "Non, je suis élève"
  end

  test "CA-12 : « Oui » ouvre le formulaire ; la recherche renvoyée sans JavaScript et le lien d'invitation ne reposent pas la question" do
    get new_teacher_registration_path(confirmed: 1)
    assert_select "form#teacher-registration-form"

    get new_teacher_registration_path, params: { school_q: "cocody" }
    assert_select "#teacher-signup-confirm", 0
    assert_select "form#teacher-registration-form"
  end

  test "CA-J1, IE-02, IE-03: without a link the form opens on step 1; three steps in order, the school search, Nom then Prénom(s)" do
    get new_teacher_registration_path(confirmed: 1)

    assert_response :success
    assert_select "h1", text: I18n.t("#{PAGE}.title")
    assert_select "main#teacher-signup[data-controller='classroom--signup-steps'][data-classroom--signup-steps-start-value='1']"
    assert_select "form#teacher-signup-school[action='#{new_teacher_registration_path}'][method=get]"
    # CA-10 : la recherche sans JavaScript part du formulaire GET distinct, jamais avec le code secret.
    assert_select "input#school_q[form=teacher-signup-school][type=search]"
    assert_select "noscript button[form=teacher-signup-school][type=submit]", text: /Chercher/
    assert_select "form#teacher-signup-school input, form#teacher-signup-school select", 0
    # Revue sécurité : seul le champ de recherche (et le bouton « Chercher ») appartient au formulaire GET, jamais le code secret.
    assert_equal [ "school_q" ], css_select("[form=teacher-signup-school]").reject { it.name == "button" }.map { it["id"] }
    assert_select "label.sr-only[for=school_q]", text: /Votre établissement/
    assert_select "select[name*=drena_public_id]", 0
    assert_select "form#teacher-registration-form[action='#{teacher_registrations_path}']" \
                  "[data-controller='identity--phone-digits']" do
      assert_equal [ "Votre numéro", "Entrez votre code secret", "Votre profil" ],
                   css_select("fieldset[data-classroom--signup-steps-target=step] > legend").map { it.text.strip }
      assert_equal %w[1 2 3], css_select("fieldset[data-classroom--signup-steps-target=step]").map { it["data-step"] }
      # Étapes 1 et 2 : « Continuer » (type button) fait avancer ; l'établissement choisi ne change plus d'étape.
      assert_select "fieldset[data-step='1'][data-continue] input[type=tel][name='teacher_registration[contact]']"
      assert_select "fieldset[data-step='1'] button[type=button]#teacher-registration-continue-1[data-action='classroom--signup-steps#continue']"
      assert_select "fieldset[data-step='2'][data-continue] button[type=button]#teacher-registration-continue-2"
      assert_select "fieldset[data-step='3'] input#school_q[aria-controls=school_results][aria-describedby=school_q_hint]"
      assert_select "fieldset[data-step='3'] turbo-frame#school_results:empty"
      assert_select "[data-action*='classroom--signup-steps#go']", 0
      assert_select "fieldset[data-step='3'] select[name='teacher_registration[material_slug]'] option[value='#{@material.slug}']", text: "SVT"
      assert_select "input[name='teacher_registration[last_name]'][required][maxlength='50'][autocomplete=family-name]" \
                    "[placeholder='Ex. : KOUASSI']"
      assert_select "input[name='teacher_registration[first_name]'][required][maxlength='80'][autocomplete=given-name]" \
                    "[placeholder='Ex. : Aya Marie']"
      assert_select "input[name='teacher_registration[full_name]'], details, #full_name_preview", 0
      assert_select "fieldset[data-step='3'] input[type=radio][name='teacher_registration[gender]']", count: 2
      assert_select "input[type=tel][name='teacher_registration[contact]'][maxlength='20'][inputmode=numeric]:not([pattern])"
      # CA-11 : le code se tape une fois, sans confirmation.
      assert_select "fieldset[data-step='2'] input[type=password][name='teacher_registration[pin]'][inputmode=numeric]" \
                    "[minlength='4'][maxlength='4'][pattern='[0-9]{4}'][autocomplete=new-password]"
      assert_select "[name*=pin_confirmation], #pin_match_status, [data-controller*=pin-match]", 0
      assert_select "#teacher-registration-number, #teacher-registration-fix-number", 0
      assert_select "input[name='teacher_registration[invite_token]']", 0
    end
    assert_select "[name*=school_code], [name*=national_code], [name*=role]", 0
    assert_select "#school-preview, #invite-link-invalid", 0
    assert_select "#signup-step-counter", text: I18n.t("#{PAGE}.step_counter", n: 1)
    assert_select "#signup-welcome", text: /Bienvenue sur Lnclass/
    assert_no_match(/Code d'établissement/, response.body)
    assert_select "a[href='#{new_session_path}']"
  end

  # CA-J4 (UDR §3.9): « Créer mon compte » on step 3, then the terms line under the button.
  test "CA-J4: step 3 holds the button « Créer mon compte » with the terms line under it" do
    get new_teacher_registration_path(confirmed: 1)

    assert_select "fieldset[data-step='3']" do
      assert_select "button[type=submit]#teacher-registration-submit", text: I18n.t("#{FORM}.submit")
      assert_select "button#teacher-registration-submit ~ p a[href='#{terms_path}']"
      assert_select "button#teacher-registration-submit ~ p a[href='#{privacy_path}']"
    end
  end

  test "the gender pills read « M. » and « Mme » (UDR enseignant §3.9)" do
    get new_teacher_registration_path(confirmed: 1)

    assert_select "#teacher-registration-gender label", count: 2 do |pills|
      assert_equal [ "M.", "Mme" ], pills.map { it.text.squish }
    end
  end

  test "CA-10: without JavaScript, the search comes back in GET and lists the active schools, each with its DRENA" do
    create_school(drena: @drena, name: "Lycée Moderne fermé", status: "inactive")

    get new_teacher_registration_path, params: { school_q: "lycée moderne" }

    assert_response :success
    assert_select "input#school_q[value='lycée moderne']"
    assert_select "turbo-frame#school_results input[type=radio][name='teacher_registration[school_public_id]']" \
                  "[value='#{@school.public_id}']:not([checked])"
    assert_select "turbo-frame#school_results label", text: /Lycée Moderne de Cocody\s+DRENA Abidjan 1/
    assert_no_match(/Lycée Moderne fermé/, response.body)
  end

  test "IE-01: a standard sign-up attaches the teacher at once, way « standard », no join request, signed in" do
    post teacher_registrations_path, params: { teacher_registration: registration_params }

    assert_redirected_to teacher_home_path
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

  # CA-J3 (UDR §3.9, ADR-0103 §4.4 amendé): one subject, with the help line; « Autre matière (facultatif) » is gone.
  test "CA-J3: step 2 asks for a single subject with its help line; a forged second subject is ignored" do
    pc = create_material(name: "Physique-Chimie", shortname: "PC")
    get new_teacher_registration_path(confirmed: 1)

    assert_select "fieldset[data-step='3'] select[name='teacher_registration[material_slug]'][required]", 1
    assert_select "select[name='teacher_registration[second_material_slug]']", 0
    assert_select "fieldset[data-step='3']", text: /#{Regexp.escape(I18n.t("#{FORM}.material_hint"))}/
    assert_no_match(/Autre matière/, response.body)

    post teacher_registrations_path, params: { teacher_registration: registration_params(material_slug: pc.slug, second_material_slug: @material.slug) }

    assert_redirected_to teacher_home_path
    assert_equal [ [ @school.id, pc.id ] ], Orm::TeacherSchoolMaterial.where(teacher: new_teacher).in_order.pluck(:school_id, :material_id)
  end

  # CA-J1 (UDR §3.5 de l'inscription élève): a server error reopens the step that holds the field.
  test "CA-J1: a 422 reopens the step of the faulty field" do
    { { contact: "" } => 1, { pin: "12" } => 2, { first_name: "  " } => 3, { school_public_id: "" } => 3, { material_slug: "" } => 3 }
      .each do |overrides, step|
        post teacher_registrations_path, params: { teacher_registration: registration_params(**overrides) }

        assert_response :unprocessable_entity
        assert_select "main#teacher-signup[data-classroom--signup-steps-start-value='#{step}']", 1, overrides.to_s
        assert_select "#signup-step-counter", text: I18n.t("#{PAGE}.step_counter", n: step)
      end
  end

  test "IE-03: the name and the first names are saved as typed, spaces reduced, case kept" do
    post teacher_registrations_path,
         params: { teacher_registration: registration_params(last_name: " N'GUESSAN ", first_name: "Konan  Jean-Baptiste") }

    assert_redirected_to teacher_home_path
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

  test "IE-17, IE-19 without JavaScript: a code out of format is refused in 422; « +225 07 01 02 03 04 » is saved cleaned" do
    post teacher_registrations_path,
         params: { teacher_registration: registration_params(contact: "+225 07 01 02 03 04", pin: "12a4") }

    assert_response :unprocessable_entity
    assert_select "#teacher_registration_pin_error", text: I18n.t("#{ERRORS}.pin.invalid")
    assert_select "input[name='teacher_registration[contact]'][value='+225 07 01 02 03 04']"
    assert_select "input[name='teacher_registration[last_name]'][value='KOUASSI']"
    assert_select "input[name='teacher_registration[first_name]'][value='Aya Marie']"
    assert_select "input[name='teacher_registration[pin]'][value]", count: 0
    assert_select "turbo-frame#school_results input[checked][value='#{@school.public_id}']"

    post teacher_registrations_path, params: { teacher_registration: registration_params(contact: "+225 07 01 02 03 04") }

    assert_redirected_to teacher_home_path
    assert Orm::User.exists?(contact: "0701020304", role: "teacher")
  end

  test "IE-11: a draft, inactive or unknown school is refused in 422 with the same message under the search, no account, none checked" do
    others = [ create_school(drena: @drena, status: "inactive"), create_school(drena: @drena, status: "draft") ].map(&:public_id)

    [ *others, "sch-inconnu" ].each do |school_public_id|
      post teacher_registrations_path, params: { teacher_registration: registration_params(school_public_id:) }

      assert_refused :school_public_id, I18n.t("#{ERRORS}.school_public_id.inclusion")
      assert_select "input#school_q[aria-invalid=true][aria-describedby~=teacher_registration_school_public_id_error]"
      assert_select "turbo-frame#school_results input", 0
    end
  end

  # CA-8 : la DRENA n'est plus un choix ; elle vient de l'établissement, quelle que soit celle envoyée.
  test "CA-8: the DRENA comes from the school chosen, whatever DRENA is sent, or none" do
    elsewhere = create_school(drena: create_drena(name: "Tiassalé"), name: "Collège Notre-Dame de la Paix")

    post teacher_registrations_path, params: { teacher_registration: registration_params(drena_public_id: @drena.public_id, school_public_id: elsewhere.public_id) }

    assert_redirected_to teacher_home_path
    assert_equal [ elsewhere.id ], Orm::TeacherSchool.where(teacher: new_teacher).pluck(:school_id)
  end

  # Revue des échecs silencieux : un établissement devenu inactif entre la recherche et l'envoi ne rend pas un 422 muet.
  test "CA-8: a school gone inactive before the sending is refused under the field, with the neutral message" do
    @school.update_column(:status, "inactive")

    post teacher_registrations_path, params: { teacher_registration: registration_params }

    assert_response :unprocessable_entity
    assert_select "#teacher_registration_school_public_id_error", text: /Cet établissement n'accepte pas d'inscription/
    assert_select "input#school_q[aria-invalid=true]"
    assert_select "turbo-frame#school_results input[type=radio]", 0
  end

  test "IE-11: a school still active comes back checked after a 422, alone in the list" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(pin: "12") }

    assert_response :unprocessable_entity
    assert_select "turbo-frame#school_results input[type=radio]", 1
    assert_select "turbo-frame#school_results input[type=radio][checked][value='#{@school.public_id}']"
  end

  test "IE-11: no school chosen: the search says so in 422" do
    post teacher_registrations_path,
         params: { teacher_registration: registration_params(drena_public_id: "", school_public_id: "") }

    assert_refused :school_public_id, I18n.t("#{ERRORS}.school_public_id.blank")
  end

  test "IE-06: the colleague's link shows the school and its DRENA, carries the token hidden, and keeps a way out" do
    token = school_token_of(create_teacher(school: @school))

    get teacher_invite_link_path(token)

    assert_response :success
    # CA-12 (numéro d'abord) : le lien ouvre l'étape 1, le numéro ; le rappel de l'établissement est au profil (étape 3).
    assert_select "main#teacher-signup[data-classroom--signup-steps-start-value='1']"
    assert_select "fieldset[data-step='1'] input[name='teacher_registration[contact]']"
    assert_select "#signup-step-counter", text: I18n.t("#{PAGE}.step_counter", n: 1)
    assert_select "#signup-welcome:not([hidden])"
    assert_select "fieldset[data-step='3'] #school-preview", text: /#{Regexp.escape(I18n.t("identity.teacher_registrations.school_preview.label"))}.*Lycée Moderne de Cocody/m
    assert_select "#school-preview", text: /Abidjan 1/
    assert_select "form#teacher-registration-form input[type=hidden][name='teacher_registration[invite_token]'][value='#{token}']"
    assert_select "a#other-school[href='#{new_teacher_registration_path}']", text: /#{Regexp.escape(I18n.t('identity.teacher_registrations.school_preview.other_school'))} ›/
    assert_select "input#school_q, turbo-frame#school_results", 0
    assert_select "select[name='teacher_registration[material_slug]']"
    assert_select "#invite-link-invalid", 0
    assert_no_match(/k7m4qz|K7M-4QZ/i, response.body)
    assert_not_includes response.body, @school.public_id
    assert_empty session.to_h.except("session_id", "_csrf_token", "csp_nonce"), "le jeton ne va pas en session"
  end

  test "IE-06: signing up by the colleague's link attaches to the school of the link, way « colleague », referral counted" do
    referrer = create_teacher(school: @school)

    post teacher_registrations_path,
         params: { teacher_registration: registration_params(invite_token: school_token_of(referrer), drena_public_id: nil,
                                                             school_public_id: nil) }

    assert_redirected_to teacher_home_path
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher: new_teacher).pluck(:school_id, :primary)
    assert_equal "colleague", joined_via
    assert_equal [ [ referrer.id, @school.id, "link" ] ],
                 Orm::Referral.where(referee: new_teacher).pluck(:referrer_id, :school_id, :source)
  end

  # ME-27, ME-28 (ADR-0094 §11, MET-8): the colleague's sponsor link has no school: the page names him and lists the
  # schools of the DRENA chosen; the sign-up records his referral with the school chosen, source « sponsor ».
  test "ME-27: the sponsor link names the colleague, keeps the token, and lets the school be chosen" do
    token = referral_token_of(create_teacher(school: create_school, first_name: "Awa", last_name: "Traoré"))

    get teacher_invite_link_path(token)

    assert_response :success
    assert_select "#sponsor-preview", text: /Awa Traoré vous invite sur Lnclass/
    assert_select "form#teacher-registration-form input[type=hidden][name='teacher_registration[invite_token]'][value='#{token}']"
    assert_select "main#teacher-signup[data-classroom--signup-steps-start-value='1']"
    assert_select "fieldset[data-step='1'] #sponsor-preview"
    assert_select "input#school_q[form=teacher-signup-school]"
    assert_select "form#teacher-signup-school[action='#{teacher_invite_link_path(token)}']"
    assert_select "#school-preview, #invite-link-invalid", 0
    get teacher_invite_link_path(token), params: { school_q: "cocody" }
    assert_select "turbo-frame#school_results label", text: /Lycée Moderne de Cocody/
  end

  test "ME-28: signing up by the sponsor link attaches to the school chosen, way « colleague », referral « sponsor »" do
    referrer = create_teacher(school: create_school)

    post teacher_registrations_path, params: { teacher_registration: registration_params(invite_token: referral_token_of(referrer)) }

    assert_redirected_to teacher_home_path
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher: new_teacher).pluck(:school_id, :primary)
    assert_equal "colleague", joined_via
    assert_equal [ [ referrer.id, @school.id, "sponsor" ] ], Orm::Referral.where(referee: new_teacher).pluck(:referrer_id, :school_id, :source)
  end

  test "ME-28: by the sponsor link, a school must still be chosen; the error keeps the colleague's banner" do
    token = referral_token_of(create_teacher(first_name: "Awa", last_name: "Traoré"))

    post teacher_registrations_path,
         params: { teacher_registration: registration_params(invite_token: token, drena_public_id: nil, school_public_id: nil) }

    assert_refused :school_public_id, I18n.t("#{ERRORS}.school_public_id.blank")
    assert_select "#sponsor-preview", text: /Awa Traoré/
    assert_equal 0, Orm::Referral.count
  end

  test "IE-07, IE-08: the direction's and the team's links give their way, without referral" do
    { direction_invite_token: "direction", team_invite_token: "team" }.each_with_index do |(column, channel), index|
      contact = "05010203#{10 + index}"

      post teacher_registrations_path,
           params: { teacher_registration: registration_params(invite_token: @school.public_send(column), contact:,
                                                               drena_public_id: nil, school_public_id: nil) }

      assert_redirected_to teacher_home_path
      teacher = Orm::User.find_by!(contact:)
      assert_equal channel, Orm::TeacherProfile.find_by!(user: teacher).joined_via
      assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher:).pluck(:school_id)
      sign_out
    end
    assert_equal 0, Orm::Referral.count
  end

  test "IE-09: an unknown link, one of an inactive school or of a withdrawn colleague opens the standard page in 200" do
    closed = create_school(drena: @drena, name: "Lycée fermé", status: "inactive")
    withdrawn = create_teacher(school: @school, anonymized_at: Time.current)

    [ "cccccccccccc", "not-a-token", closed.team_invite_token, school_token_of(withdrawn), referral_token_of(withdrawn) ].each do |token|
      get teacher_invite_link_path(token)

      assert_response :success, token
      assert_select "main#teacher-signup[data-classroom--signup-steps-start-value='1']", 1, token
      assert_select "#invite-link-invalid[role=alert]", text: I18n.t("#{PAGE}.invite_invalid")
      assert_select "input#school_q"
      assert_select "input[name='teacher_registration[invite_token]'], #school-preview", 0
      assert_no_match(/Lycée fermé/, response.body)
    end
  end

  test "IE-09: a link that became invalid before the submit falls back to the school chosen, way « standard »" do
    referrer = create_teacher(school: create_school(drena: @drena, status: "inactive"))

    post teacher_registrations_path,
         params: { teacher_registration: registration_params(invite_token: school_token_of(referrer)) }

    assert_redirected_to teacher_home_path
    assert_equal "standard", joined_via
    assert_equal 0, Orm::Referral.count
  end

  test "an error after a valid link keeps the banner and the token, never the PINs" do
    token = @school.team_invite_token

    post teacher_registrations_path,
         params: { teacher_registration: registration_params(invite_token: token, pin: "12") }

    assert_refused :pin, I18n.t("#{ERRORS}.pin.invalid")
    assert_select "#school-preview", text: /Lycée Moderne de Cocody/
    assert_select "input[type=hidden][name='teacher_registration[invite_token]'][value='#{token}']"
    assert_select "input#school_q", 0
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

    assert_redirected_to teacher_home_path
    event = Orm::AuditEvent.sole
    assert_equal [ "school.changed", new_teacher.id, "School", @school.id, { "change" => "teacher_joined", "via" => "standard" } ],
                 [ event.action, event.actor_id, event.subject_type, event.subject_id, event.metadata ]
  end

  test "IE-10: from a colleague's link, « Ce n'est pas votre établissement ? » then the sign-up: way « standard », no referral" do
    get teacher_invite_link_path(school_token_of(create_teacher(school: @school)))
    other_school = css_select("a#other-school").first["href"]

    get other_school

    assert_response :success
    assert_select "input[name='teacher_registration[invite_token]']", 0
    post teacher_registrations_path, params: { teacher_registration: registration_params }

    assert_redirected_to teacher_home_path
    assert_equal "standard", joined_via
    assert_equal 0, Orm::Referral.count
    assert_equal "standard", Orm::AuditEvent.sole.metadata["via"]
  end

  test "a way forged in the POST is ignored: standard without a token, colleague with a valid colleague's token" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(joined_via: "team") }

    assert_redirected_to teacher_home_path
    assert_equal "standard", joined_via
    sign_out
    referrer = create_teacher(school: @school)

    post teacher_registrations_path,
         params: { teacher_registration: registration_params(contact: "05 01 02 03 99", joined_via: "direction",
                                                             invite_token: referral_token_of(referrer)) }

    assert_redirected_to teacher_home_path
    assert_equal "colleague", Orm::TeacherProfile.find_by!(user: Orm::User.find_by!(contact: "0501020399")).joined_via
  end

  test "IE-02: the old code link /e/K7M-4QZ answers 404" do
    get "/e/K7M-4QZ"

    assert_response :not_found
    assert_no_match(/Lycée Moderne de Cocody/, response.body)
  end

  # IE-13, amended by ADR-0094 (UDR-0099 §3.4): a signed-in teacher who opens a link is asked to join its school.
  test "IE-13: a signed-in person who opens the page is sent home, a teacher who opens a link is asked to join; a POST is refused" do
    sign_in_as create_teacher

    get new_teacher_registration_path(confirmed: 1)
    assert_redirected_to teacher_home_path

    get teacher_invite_link_path(@school.team_invite_token)
    assert_redirected_to teacher_school_join_path(@school.team_invite_token)

    post teacher_registrations_path, params: { teacher_registration: registration_params }
    assert_response :forbidden
    assert_not Orm::User.exists?(contact: "0501020304")
  end

  test "a role added by hand is ignored, the account is a teacher" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(role: "team", team_role: "admin") }

    assert_redirected_to teacher_home_path
    assert_equal [ "teacher", nil ], Orm::User.where(contact: "0501020304").pick(:role, :team_role)
  end

  test "an unknown subject is refused in 422" do
    post teacher_registrations_path, params: { teacher_registration: registration_params(material_slug: "latin") }

    assert_refused :material_slug, I18n.t("#{ERRORS}.material_slug.inclusion")
  end

  test "a sixth attempt in a minute receives 429 in the form" do
    6.times { post teacher_registrations_path, params: { teacher_registration: registration_params(pin: "12") } }

    assert_response :too_many_requests
    assert_select "[role=alert]", text: I18n.t("errors.codes.rate_limited")
    assert_select "main#teacher-signup[data-classroom--signup-steps-start-value='1']"
    assert_select "#signup-step-counter", text: I18n.t("#{PAGE}.step_counter", n: 1)
  end

  test "UDR-0079 §3.6: the eleventh link opened in a minute receives 429, without the school; the form keeps its own count" do
    10.times { |index| get teacher_invite_link_path(index.even? ? @school.team_invite_token : "cccccccccccc") }

    get teacher_invite_link_path(@school.team_invite_token)

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /#{Regexp.escape(I18n.t('errors.codes.rate_limited'))}/
    assert_not_includes response.body, "Lycée Moderne de Cocody"
    assert_select "form#teacher-registration-form", 0

    get new_teacher_registration_path(confirmed: 1)
    assert_response :success
  end

  # Chantier connexion-numero-d-abord (UDR-0189 §3.5).
  def arrive_from_login(contact = "0501020304")
    post session_path, params: { session: { contact: } }
    assert_redirected_to new_session_path
  end

  test "CA-4: a number from /login taken in the meantime is refused on the code step, with its message" do
    arrive_from_login
    create_student(contact: "0501020304")

    post teacher_registrations_path, params: { teacher_registration: registration_params.except(:contact) }

    assert_response :unprocessable_entity
    assert_select "main#teacher-signup[data-classroom--signup-steps-start-value='2']"
    assert_select "fieldset[data-step='2'] #teacher-registration-refusal[role=alert]",
                  text: I18n.t("activemodel.errors.models.dtos/identity/teacher_registration_input.attributes.contact.taken")
  end

  test "CA-4: a number from /login more than 30 minutes old is no longer taken over" do
    arrive_from_login

    travel 31.minutes do
      get new_teacher_registration_path(confirmed: 1)

      assert_select "main#teacher-signup[data-classroom--signup-steps-start-value='1']"
      assert_select "#teacher-registration-number", 0
    end
  end

  test "CA-4: from « pas de compte » on /login, the sign-up opens on the code, the number recalled, never asked again" do
    arrive_from_login

    get new_teacher_registration_path(confirmed: 1)

    assert_response :success
    assert_select "main#teacher-signup[data-classroom--signup-steps-start-value='2']"
    assert_select "fieldset[data-step='1'], input[name='teacher_registration[contact]']", 0
    assert_select "fieldset[data-step='2'] #teacher-registration-number", text: /05 01 02 03 04/
    assert_select "a#teacher-registration-fix-number[href='#{new_session_path(fresh: 1)}']", text: I18n.t("#{FORM}.not_my_number")
    assert_select "#signup-step-counter", text: I18n.t("#{PAGE}.step_counter", n: 2)
    assert_select "#signup-back[hidden]"
  end

  test "CA-4: the account is created with the number kept, the code typed once; the entry is then forgotten" do
    arrive_from_login

    post teacher_registrations_path, params: { teacher_registration: registration_params.except(:contact) }

    assert_redirected_to teacher_home_path
    assert Orm::User.authenticate_by(contact: "0501020304", pin: "4821")
    sign_out
    get new_teacher_registration_path(confirmed: 1)
    assert_select "#teacher-registration-number", 0
    assert_select "fieldset[data-step='1'] input[name='teacher_registration[contact]']"
  end

  test "CA-4: an error after « pas de compte » reopens the profile, the number still recalled, the code never sent back" do
    arrive_from_login

    post teacher_registrations_path, params: { teacher_registration: registration_params(first_name: " ").except(:contact) }

    assert_response :unprocessable_entity
    assert_select "main#teacher-signup[data-classroom--signup-steps-start-value='3']"
    assert_select "#teacher-registration-number", text: /05 01 02 03 04/
    assert_select "input[name='teacher_registration[pin]'][value]", 0
  end

  test "CA-4: a number known to /login is never recalled here (only a number without an account is)" do
    create_teacher(contact: "0501020304")
    arrive_from_login

    get new_teacher_registration_path(confirmed: 1)

    assert_select "#teacher-registration-number", 0
    assert_select "fieldset[data-step='1'] input[name='teacher_registration[contact]']:not([value])"
  end

  test "CA-11: a direct sign-up (number, code once, profile, no school code) creates the account in the school chosen, way « standard »" do
    post teacher_registrations_path, params: { teacher_registration: registration_params }

    assert_redirected_to teacher_home_path
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher: new_teacher).pluck(:school_id)
    assert_equal "standard", joined_via
  end
end
