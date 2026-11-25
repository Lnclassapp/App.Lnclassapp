require "application_system_test_case"

# CA-10 (ADR adresse-publique-etablissement §4) : du QR de l'établissement au compte créé. L'adresse /ecole/<id> ouvre l'entrée
# élève ; numéro inconnu, code et confirmation : l'inscription s'ouvre, l'établissement choisi et ses niveaux proposés ; l'élève
# choisit niveau et classe, et son compte est créé dans cette classe.
class SchoolSignupLinkTest < ApplicationSystemTestCase
  FORM = "classroom.student_registrations.form".freeze

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    level = create_level(name: "6ème")
    @classroom = create_classroom(school: @school, level:, name: "6ème 1")
    create_school(name: "Collège Moderne de Cocody")
  end

  test "CA-10: from /ecole/<id> to the account created in the chosen classroom, the school already chosen" do
    visit school_signup_link_path(@school.public_id)

    assert_current_path new_student_entry_path
    pass_student_entry
    assert_checked_field @school.name, visible: :all
    within("turbo-frame#picker_levels") { choose "6ème" }
    within("turbo-frame#picker_classrooms") { choose "6ème 1" }
    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    click_on I18n.t("#{FORM}.submit")

    assert_toast I18n.t("classroom.student_registrations.create.welcome")
    assert_current_path student_home_path
    student = Orm::User.find_by!(contact: "0701020304", role: "student")
    assert_equal [ @classroom.id ], Orm::ClassroomStudent.where(student:, left_at: nil).pluck(:classroom_id)
  end
end
