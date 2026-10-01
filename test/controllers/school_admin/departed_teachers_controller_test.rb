require "test_helper"

# GD-21 (ADR-0071 §4.6, UDR-0056 §3.4): « Enseignants retirés », sister page of « Enseignants »: the open departures of
# the direction's own school, a « Réintégrer » button per row on an active school, an empty state, 403 to other roles.
class SchoolAdmin::DepartedTeachersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @other = create_school(name: "Lycée Classique d'Abidjan")
    @admin = create_school_admin(school: @school)
  end

  def t(key, **) = I18n.t("school_admin.departed_teachers.index.#{key}", **)

  def departed(school: @school, detached_at: 2.days.ago, **attributes)
    create_teacher(school: nil, **attributes).tap do |teacher|
      create_teacher_departure(teacher:, school:, detached_by: @admin, detached_at:)
    end
  end

  test "GD-21 : un seul enseignant retiré listé, avec la date de son retrait et son bouton « Réintégrer »" do
    awa = departed(first_name: "Awa", last_name: "Koné", material: create_material(name: "Mathématiques"),
                   detached_at: Time.zone.local(2026, 9, 28, 10))
    departed(last_name: "Ailleurs").tap { Orm::TeacherSchool.create!(teacher: it, school: @other, primary: true) }
    departed(school: @other, last_name: "DeB")
    sign_in_as @admin

    get school_admin_departed_teachers_path

    assert_response :success
    assert_select "title", text: /\A#{Regexp.escape(t('page_title'))}/
    assert_select "aside nav a[aria-current=page][href='#{school_admin_teachers_path}']"
    assert_select "a#back-to-teachers[href='#{school_admin_teachers_path}']", text: /#{t('back')}/
    assert_select "h1", text: t("title")
    assert_select "main", text: /Lycée Moderne de Bouaké/
    assert_select "#departed_teachers ul[aria-label=?] > li", t("list_label"), 1
    assert_select "li#departed_teacher_#{awa.public_id}" do
      assert_select ".font-medium", text: "Awa Koné"
      assert_select "*", text: /Mathématiques/
      assert_select ".text-mute", text: t("detached_on", date: I18n.l(Date.new(2026, 9, 28), format: :long))
      assert_select "form#reinstate-#{awa.public_id}-form[action='#{school_admin_teacher_reinstatement_path(awa.public_id)}'][method=post]" do
        assert_select "button[type=submit][aria-label=?]", t("reinstate_label", name: "Awa Koné"), text: /#{t('reinstate')}/
      end
    end
    assert_not_includes response.body, "Ailleurs"
    assert_not_includes response.body, "DeB"
  end

  test "un enseignant sans matière : un tiret, « non calculé » pour le lecteur d'écran" do
    Orm::TeacherProfile.where(user: departed).delete_all
    sign_in_as @admin

    get school_admin_departed_teachers_path

    assert_select "#departed_teachers li span[aria-hidden=true]", text: "—"
    assert_select "#departed_teachers li .sr-only", text: t("missing")
  end

  test "GD-21 : sans enseignant retiré, l'état vide « Aucun enseignant retiré »" do
    departed(school: @other)
    sign_in_as @admin

    get school_admin_departed_teachers_path

    assert_response :success
    assert_select "div#departed_teachers", text: /#{t('empty.title')}/
    assert_select "div#departed_teachers", text: /#{Regexp.escape(t('empty.description'))}/
    assert_select "#departed_teachers li", 0
  end

  test "un établissement inactif : la liste se lit, sans bouton « Réintégrer »" do
    departed
    @school.update!(status: "inactive")
    sign_in_as @admin

    get school_admin_departed_teachers_path

    assert_response :success
    assert_select "#departed_teachers li", 1
    assert_select "#departed_teachers form", 0
  end

  test "un élève, un enseignant, l'équipe et une direction sans établissement reçoivent 403 ; un visiteur se connecte" do
    get school_admin_departed_teachers_path
    assert_redirected_to new_session_path

    [ create_student, create_teacher(school: @school), create_team_member, create_user(role: "school_admin") ].each do |user|
      sign_in_as user
      get school_admin_departed_teachers_path
      assert_response :forbidden, user.role
      sign_out
    end
  end
end
