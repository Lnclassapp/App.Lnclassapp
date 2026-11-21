require "test_helper"

# CA-9 (ADR adresse-publique-etablissement §4, M1 à M5) : /ecole/<identifiant public> garde l'établissement actif en session et
# mène à l'entrée élève ; inconnu, inactif ou en brouillon : la même redirection, rien gardé ; un connecté va à son accueil ;
# la 61e ouverture d'une minute reçoit 429.
class Classroom::SchoolSignupLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @level = create_level(name: "6ème")
    create_classroom(school: @school, level: @level, name: "6ème 1")
  end

  def enter_as_new_student(contact: "0701020304", pin: "4821")
    post student_entries_path, params: { student_entry: { contact:, pin: } }
    post student_entries_path, params: { student_entry: { pin_confirmation: pin } }
  end

  test "CA-9: an active school is kept and the visitor goes to /student; the sign-up then opens with that school chosen" do
    get school_signup_link_path(@school.public_id)

    assert_redirected_to new_student_entry_path
    enter_as_new_student
    get new_student_registration_path

    assert_response :success
    assert_select "input[type=radio][name='student_registration[school_public_id]'][value=?][checked]", @school.public_id
  end

  test "CA-9: an explicit school in the request wins over the kept one" do
    other = create_school(name: "Collège Moderne de Cocody")
    get school_signup_link_path(@school.public_id)
    enter_as_new_student

    get new_student_registration_path, params: { student_registration: { school_public_id: other.public_id } }

    assert_select "input[type=radio][name='student_registration[school_public_id]'][value=?][checked]", other.public_id
  end

  test "CA-9: unknown, inactive and draft schools get the same redirect and keep nothing" do
    inactive = create_school(name: "Collège fermé", status: "inactive")
    draft = create_school(name: "Collège brouillon", status: "draft")
    kept = []

    [ "Zzzzzzzzzzzzzz", inactive.public_id, draft.public_id ].each do |public_id|
      get school_signup_link_path(public_id)
      assert_redirected_to new_student_entry_path
      kept << response.headers["Location"]
      enter_as_new_student
      get new_student_registration_path
      assert_select "input[name='student_registration[school_public_id]'][checked]", false
      reset!
    end

    assert_equal 1, kept.uniq.size
  end

  test "CA-9: a signed-in student opening the address goes to their home" do
    student = create_student(classroom: create_classroom(school: @school, level: @level, name: "6ème 2"))
    sign_in_as student

    get school_signup_link_path(@school.public_id)

    assert_redirected_to student_home_path
  end

  test "CA-9: the 61st opening of a minute from the same address receives 429 and says nothing" do
    60.times { get school_signup_link_path(@school.public_id) }
    assert_redirected_to new_student_entry_path

    get school_signup_link_path(@school.public_id)

    assert_response :too_many_requests
    assert_not_includes response.body, @school.name
  end
end
