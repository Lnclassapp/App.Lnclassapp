require "application_system_test_case"

# Lot E, preuve bout en bout : les chemins d'erreur du PRD (§3, chemins alternatifs), joués par les vrais
# boutons, comme un utilisateur qui se trompe. Chaque scénario vérifie aussi ce qui ne doit PAS arriver :
# aucun compte créé, aucune tentative écrite, aucune donnée d'une autre classe, aucun second import.
class ErrorPathsTest < ApplicationSystemTestCase
  setup { @import_dir = Dir.mktmpdir("error_paths") }
  teardown { FileUtils.remove_entry(@import_dir) }

  # --- Code de classe invalide (ID-02, CL-07) ---------------------------------------------------------------

  test "a visitor with a wrong class code is told so, then finds the class with a code typed anyhow" do
    classroom = create_classroom(name: "Tle D 1", join_code: "kfm37")
    users = Orm::User.count

    visit new_join_code_path
    # A well-formed code leaves by itself at its fifth character (UDR-0054 §3.6): no click on « Continuer ».
    fill_in "join[code]", with: "ZZZ99"

    # recette-v1-defauts, D1 : le code inconnu est refusé dans son champ, sur /join même.
    assert_selector "#join_code_error", text: t("classroom.joins.new.invalid_code.title")
    assert_current_path new_join_code_path
    assert_no_selector "#join-form"

    fill_in "join[code]", with: "k1"
    click_on t("classroom.join_codes.new.submit")
    assert_text t("classroom.join_codes.create.invalid")

    fill_in "join[code]", with: " Kfm 37 "
    assert_current_path join_classroom_path("kfm37")
    assert_selector "#classroom-preview", text: "Tle D 1"

    # Un ancien code, remplacé depuis, ne mène plus nulle part.
    classroom.update!(join_code: "pqr45")
    visit join_classroom_path("KFM37")
    assert_selector "h1", text: t("classroom.joins.new.invalid_code.title")
    assert_no_text "Tle D 1"
    assert_equal users, Orm::User.count
  end

  # --- Classe pleine, classe archivée (CL-06) -----------------------------------------------------------------

  test "a visitor who fills the whole form for a full class is refused with the reason and gets no account" do
    classroom = create_classroom(name: "Tle D 2", join_code: "bcd23", max_students: 1)
    create_student(classroom:)
    users = Orm::User.count

    visit new_join_code_path
    fill_in "join[code]", with: "BCD23"
    fill_in_student_signup(contact: "07 11 22 33 44")
    click_on t("classroom.joins.signup_form.submit")

    assert_selector "#join-form [role=alert]", text: join_refusal(:classroom_full)
    assert_equal users, Orm::User.count
    assert_equal 1, Orm::ClassroomStudent.where(classroom:).count
    visit student_home_path
    assert_current_path new_session_path
  end

  test "a visitor with the code of an archived class is refused with the reason and gets no account" do
    create_classroom(name: "Tle D 3", join_code: "cde34", status: "archived")
    users = Orm::User.count

    visit join_classroom_path("cde34")
    fill_in_student_signup(contact: "07 11 22 33 45")
    click_on t("classroom.joins.signup_form.submit")

    assert_selector "#join-form [role=alert]", text: join_refusal(:classroom_archived)
    assert_equal users, Orm::User.count
  end

  # --- Réponse vide (AS-09) -----------------------------------------------------------------------------------

  test "a student who validates without choosing gets the error in the question card, then answers normally" do
    exercise = create_exercise(title: "Méiose")
    # UDR-0013, amendement du 2026-10-01 : la classe de l'élève est du niveau du cours de l'exercice.
    classroom = create_classroom(level: exercise.essential.course.level)
    student = create_student(classroom:)
    create_assignment(classroom:, assignable: exercise)

    sign_in_as student
    click_on t("classroom.student_homes.assigned_exercise.start")
    assert_selector "#question-card", text: t("assessment.exercise_sessions.question_card.number", number: 1, total: 2)

    assert_no_page_reload do
      click_on t("assessment.exercise_sessions.question_card.submit")
      assert_selector "#question-card #attempt-errors", text: attempt_error(:answer_ids, :blank)
    end
    assert_equal 0, Orm::QuestionAttempt.count

    assert_no_page_reload do
      choose "Proposition 1"
      click_on t("assessment.exercise_sessions.question_card.submit")
      assert_text t("assessment.exercise_sessions.feedback_card.verdict.success")
    end
    assert_no_selector "#attempt-errors"
    assert_equal 1, Orm::QuestionAttempt.count
  end

  # --- Enseignant hors de sa classe (TR-cadre-4) ---------------------------------------------------------------

  test "a teacher who opens another class, its course or one of its results sees nothing of it" do
    school = create_school
    own = create_classroom(school:, name: "Tle D 1")
    other = create_classroom(school:, name: "Tle D 2", join_code: "xyz89")
    teacher = create_teacher(school:, classrooms: [ own ])
    create_teacher(school:, classrooms: [ other ])
    stranger = create_student(classroom: other, last_name: "Yao", first_name: "Clarisse")
    course = create_course(name: "Génétique")
    create_assignment(classroom: other, assignable: create_exercise(essential: create_essential(course:)))
    session = create_exercise_session(student: stranger, status: "completed")

    sign_in_as teacher
    assert_text "Tle D 1"
    assert_no_text "Tle D 2"

    [ classroom_path(other.public_id), classroom_course_path(other.public_id, course.slug),
      exercise_session_result_path(session.public_id) ].each do |path|
      visit path
      assert_text t("errors.forbidden.title")
      assert_no_text(/xyz89/i)
      assert_no_text "Clarisse"
      assert_no_text "Yao"
    end
  end

  # --- PIN oublié, code émis par l'enseignant, nouveau PIN (ID-15, TR-cadre-2) --------------------------------

  test "a locked-out student gets a code from the teacher, types it as shown, and signs in with the new PIN only" do
    classroom = create_classroom(name: "Tle D 1")
    teacher = create_teacher(school: classroom.school, classrooms: [ classroom ])
    student = create_student(classroom:, pin: "2468")
    # 20 échecs consécutifs : le compte est verrouillé jusqu'à la récupération du PIN, même avec le bon PIN.
    # (Les jouer à l'écran heurterait la limite de 5 connexions par minute et par adresse.)
    20.times { create_login_attempt(contact: student.contact, created_at: 1.minute.ago) }

    visit new_session_path
    sign_in_with(student.contact, "2468")
    assert_text t("errors.locked.until_recovery")

    code = using_session(:teacher) do
      sign_in_as teacher
      click_on "Tle D 1"
      assert_no_page_reload do
        within("#student_#{student.public_id}") { click_on t("classroom.classrooms.roster.issue_code") }
        assert_selector "#pin-recovery-code-modal"
        assert_toast t("identity.pin_recovery_codes.create.issued")
      end
      assert_no_selector "#toasts", text: find("#pin-recovery-code").text
      find("#pin-recovery-code").text
    end
    assert_match(/\A\d{4} \d{4}\z/, code)

    click_on t("identity.sessions.new.forgot_pin")
    reset_pin(student.contact, code:, pin: "7351")
    assert_text t("identity.pin_resets.create.pin_changed")

    click_on t("identity.sessions.new.forgot_pin")
    reset_pin(student.contact, code:, pin: "1111")
    assert_text t("activemodel.errors.models.dtos/identity/pin_reset_input.attributes.base.invalid_recovery")

    click_on t("identity.pin_resets.new.back")
    sign_in_with(student.contact, "2468")
    assert_text t("activemodel.errors.models.dtos/identity/credentials_input.attributes.base.invalid_credentials")
    sign_in_with(student.contact, "7351")
    assert_current_path student_home_path, wait: SIGN_IN_WAIT
  end

  # --- Équipe sans second facteur (TR-cadre-5, F-07) ---------------------------------------------------------

  test "a team member past the PIN but not the TOTP reaches no team page, and a TOTP code serves only once" do
    member = create_team_member

    visit new_session_path
    sign_in_with(member.contact, "2468")
    assert_current_path new_identity_second_factor_path, wait: SIGN_IN_WAIT
    assert_no_team_page(new_identity_second_factor_path)

    # The code leaves by itself at the sixth digit (UDR-0054 §3.6): no click on « Vérifier ».
    fill_in "second_factor[code]", with: wrong_totp(member)
    assert_text t("activemodel.errors.models.dtos/identity/second_factor_code_input.attributes.code.invalid")
    assert_no_team_page(new_identity_second_factor_path)

    code = ROTP::TOTP.new(member.totp_secret).now
    fill_in "second_factor[code]", with: code
    assert_current_path team_home_path, wait: SIGN_IN_WAIT

    sign_out
    visit new_session_path
    sign_in_with(member.contact, "2468")
    fill_in "second_factor[code]", with: code
    assert_text t("activemodel.errors.models.dtos/identity/second_factor_code_input.attributes.code.invalid")
    assert_no_team_page(new_identity_second_factor_path)
  end

  test "a team member who never enrolled a TOTP is held on the enrollment page" do
    member = create_team_member(second_factor: false)

    visit new_session_path
    sign_in_with(member.contact, "2468")
    assert_current_path new_identity_second_factor_enrollment_path, wait: SIGN_IN_WAIT
    assert_no_team_page(new_identity_second_factor_enrollment_path)
  end

  # --- Second import du même type pendant qu'un premier tourne (TR-28, ADR-0039) ------------------------------

  test "a second import of the same kind is refused in the modal while the first one waits, another kind is not" do
    sign_in_as create_team_member
    click_on t("shared.navigation.imports"), match: :first

    assert_no_page_reload do
      upload_import(:schools, "ecoles-1.json")
      assert_selector "#import-tracking-modal", text: t("teams.imports.statuses.queued")
    end
    within("#import-tracking-modal") { click_on t("teams.imports.create.close") }

    assert_no_page_reload do
      upload_import(:schools, "ecoles-2.json")
      assert_selector "#import-upload-modal [role=alert]", text: already_running
    end
    assert_equal 1, Orm::ImportReport.where(kind: "schools").count
    within("#import-upload-modal") { click_on t("teams.imports.new.cancel") }

    assert_no_page_reload do
      upload_import(:course_tree, "cours.json")
      assert_selector "#import-tracking-modal", text: t("teams.imports.statuses.queued")
    end
    assert_equal 2, Orm::ImportReport.count
  end

  test "an import interrupted for more than 10 minutes no longer blocks the next one and ends failed" do
    stale = create_import_report(kind: "schools", status: "importing", started_at: 11.minutes.ago)

    sign_in_as create_team_member
    click_on t("shared.navigation.imports"), match: :first
    assert_no_page_reload do
      upload_import(:schools, "ecoles.json")
      assert_selector "#import-tracking-modal", text: t("teams.imports.statuses.queued")
    end
    assert_equal "failed", stale.reload.status
    assert_equal 2, Orm::ImportReport.where(kind: "schools").count
  end

  test "an import never picked up for more than 10 minutes no longer blocks the next one and ends failed" do
    never_claimed = create_import_report(kind: "schools", status: "queued", created_at: 11.minutes.ago)

    sign_in_as create_team_member
    click_on t("shared.navigation.imports"), match: :first
    assert_no_page_reload do
      upload_import(:schools, "ecoles.json")
      assert_selector "#import-tracking-modal", text: t("teams.imports.statuses.queued")
    end
    assert_equal "failed", never_claimed.reload.status
    assert_equal 2, Orm::ImportReport.where(kind: "schools").count
  end

  private

  def t(key, **options) = I18n.t(key, **options)

  def join_refusal(reason)
    t("activemodel.errors.models.dtos/classroom/join_with_code_input.attributes.base.#{reason}")
  end

  def attempt_error(attribute, reason)
    t("activemodel.errors.models.dtos/assessment/attempt_input.attributes.#{attribute}.#{reason}")
  end

  def already_running
    t("activemodel.errors.models.dtos/catalog/import_upload_input.attributes.kind.already_running")
  end

  def fill_in_student_signup(contact:)
    fill_in "join[last_name]", with: "Kouassi"
    fill_in "join[first_name]", with: "Aya Marie"
    choose t("genders.female")
    fill_in "join[contact]", with: contact
    fill_in "join[pin]", with: "4821"
    fill_in "join[pin_confirmation]", with: "4821"
  end

  def sign_in_with(contact, pin)
    fill_in "session[contact]", with: contact
    fill_in "session[pin]", with: pin
    click_on t("identity.sessions.new.submit")
  end

  # Le code tel que l'enseignant le lit à l'écran, espace comprise.
  def reset_pin(contact, code:, pin:)
    fill_in "pin_reset[contact]", with: contact
    fill_in "pin_reset[code]", with: code
    fill_in "pin_reset[pin]", with: pin
    fill_in "pin_reset[pin_confirmation]", with: pin
    click_on t("identity.pin_resets.new.submit")
  end

  def wrong_totp(member)
    (ROTP::TOTP.new(member.totp_secret).now.to_i + 1).modulo(1_000_000).to_s.rjust(6, "0")
  end

  def assert_no_team_page(held_on)
    [ team_home_path, schools_path, teams_imports_path, "/teams/jobs" ].each do |path|
      visit path
      assert_current_path held_on
    end
  end

  def upload_import(kind, filename)
    click_on t("teams.imports.index.new")
    within("#new-import-menu") { click_on t("import_kinds.#{kind}") }
    within("#import-upload-modal") do
      attach_file "import[files][]", import_file(kind, filename)
      click_on t("teams.imports.new.submit")
    end
  end

  def import_file(kind, filename)
    body = { format: "lnclass.#{kind}", version: 1, kind => [] }
    File.join(@import_dir, filename).tap { File.write(it, JSON.generate(body)) }
  end
end
