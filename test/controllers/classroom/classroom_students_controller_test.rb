require "test_helper"

# IL-14, IL-12 pour le retrait, IL-21 (ADR-0083 §4.5, UDR-0079 §3.7) : « Retirer de la classe » répond en Turbo Stream —
# ligne retirée, titre de la liste et effectif recomptés, toast — ; la liste vidée retrouve son état vide. Le compte, les
# sessions et les résultats de l'élève restent. Enseignant de la classe, direction de l'établissement et équipe accordés ;
# enseignant d'une autre classe, direction d'un autre établissement : 404 ; élève : 403.
class Classroom::ClassroomStudentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school
    @classroom = create_classroom(school: @school, name: "3e 2", max_students: 60)
    @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
    @koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao", joined_at: 2.days.ago)
    @awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba", joined_at: 1.day.ago)
    @ali = create_student(classroom: @classroom, first_name: "Ali", last_name: "Cissé", joined_via: "code", joined_at: 1.year.ago)
  end

  def tr(key, **) = I18n.t("classroom.classrooms.roster.#{key}", **)
  def membership(student) = Orm::ClassroomStudent.find_by!(classroom: @classroom, student:)
  def remove(student = @koffi, classroom: @classroom, **) = delete(classroom_student_path(classroom.public_id, student.public_id), **)

  def assert_still_member(student = @koffi)
    row = membership(student)
    assert_nil row.left_at
    assert_nil row.removed_at
  end

  test "IL-14 : l'enseignant retire Koffi : ligne retirée, titre et effectif recomptés, toast, focus au titre" do
    session = create_exercise_session(student: @koffi, status: "completed", score_percent: 70)
    sign_in_as @teacher

    remove as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=remove][target=student_#{@koffi.public_id}]"
    assert_select "turbo-stream[action=replace][target=classroom_roster_title] template" do
      assert_select "h2#classroom_roster_title[tabindex='-1'][data-controller=autofocus][data-autofocus-target=field]",
                    text: /#{tr('title', count: 2)}/
      assert_select "h2 span", text: tr("new_count", count: 1)
    end
    assert_select "turbo-stream[action=update][target=classroom_headcount] template",
                  text: I18n.t("classroom.classrooms.header.headcount", count: 2, max: 60)
    assert_select "turbo-stream[action=update][target=classroom_roster_count] template", text: tr("count", count: 2)
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(tr('removed', name: 'Koffi Yao'))}/
    assert_select "turbo-stream[target=classroom_roster]", 0

    row = membership(@koffi)
    assert_not_nil row.left_at
    assert_equal [ row.left_at, @teacher.id ], [ row.removed_at, row.removed_by_id ]
    assert_still_member @awa
    assert Orm::User.exists?(@koffi.id)
    assert_equal 70, Orm::ExerciseSession.find(session.id).score_percent
  end

  test "IL-14 : après une recherche, le compte de la liste filtrée suit, l'effectif reste celui de la classe" do
    sign_in_as @teacher

    remove @awa, params: { q: "a" }, as: :turbo_stream

    assert_select "turbo-stream[action=update][target=classroom_roster_count] template", text: tr("count", count: 2)
    assert_select "turbo-stream[action=replace][target=classroom_roster_title] template h2", text: /#{tr('title', count: 2)}/
  end

  test "IL-14 : le dernier élève retiré, la liste retrouve son état vide, titre focalisé" do
    [ @awa, @ali ].each { membership(it).update!(left_at: Time.current) }
    sign_in_as @teacher

    remove as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=replace][target=classroom_roster] template section#classroom_roster" do
      assert_select "h2#classroom_roster_title[data-controller=autofocus]", text: /#{tr('title', count: 0)}/
      assert_select "#classroom_roster_empty", text: /#{tr('empty_title')}/
      assert_select "li", 0
    end
    assert_select "turbo-stream[action=remove]", 0
    assert_select "turbo-stream[action=update][target=classroom_headcount] template",
                  text: I18n.t("classroom.classrooms.header.headcount", count: 0, max: 60)
  end

  test "IL-14 : une recherche qui ne garde plus personne dit qu'aucun élève ne correspond" do
    sign_in_as @teacher

    remove params: { q: "koffi" }, as: :turbo_stream

    assert_select "turbo-stream[action=replace][target=classroom_roster] template" do
      assert_select "h2#classroom_roster_title", text: /#{tr('title', count: 2)}/
      assert_select "#classroom_roster_list [aria-live=polite]", text: tr("no_match")
      assert_select "input[name=q][value=koffi]"
    end
  end

  test "repli HTML : 303 vers la page de la classe, avec la notice" do
    sign_in_as @teacher

    remove

    assert_redirected_to classroom_path(@classroom.public_id)
    assert_equal 303, response.status
    assert_equal tr("removed", name: "Koffi Yao"), flash[:notice]
  end

  test "IL-12 : la direction de l'établissement retire ; son repli HTML mène à sa page de la classe" do
    admin = create_school_admin(school: @school)
    sign_in_as admin

    remove

    assert_redirected_to school_admin_classroom_path(@classroom.public_id)
    assert_equal admin.id, membership(@koffi).removed_by_id
  end

  test "IL-12 : l'équipe retire" do
    member = create_team_member
    sign_in_as member

    remove as: :turbo_stream

    assert_response :success
    assert_equal member.id, membership(@koffi).removed_by_id
  end

  test "IL-21 : un second retrait du même élève réussit sans erreur ; un seul départ, celui du premier" do
    sign_in_as @teacher
    remove as: :turbo_stream
    first = membership(@koffi).removed_at
    sign_out
    sign_in_as create_school_admin(school: @school)

    remove as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(tr('removed', name: 'Koffi Yao'))}/
    assert_equal [ first, @teacher.id ], membership(@koffi).slice(:removed_at, :removed_by_id).values
  end

  test "IL-12 : un enseignant d'une autre classe reçoit 404, en toast d'erreur ; rien n'est écrit" do
    sign_in_as create_teacher(school: @school, classrooms: [ create_classroom(school: @school) ])

    remove as: :turbo_stream

    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t('errors.codes.not_found')}/
    assert_no_match(/Koffi/, response.body)
    assert_still_member

    remove
    assert_response :not_found
  end

  test "IL-12 : la direction d'un autre établissement reçoit 404 ; rien n'est écrit" do
    sign_in_as create_school_admin(school: create_school)

    remove as: :turbo_stream

    assert_response :not_found
    assert_still_member
  end

  test "IL-12 : un élève, même de la classe, reçoit 403 ; rien n'est écrit" do
    sign_in_as @awa

    remove as: :turbo_stream

    assert_response :forbidden
    assert_still_member
  end

  test "un élève d'une autre classe, ou une classe inconnue : 404, le nom ne sort pas" do
    outsider = create_student(classroom: create_classroom(school: @school), first_name: "Zoé", last_name: "Ailleurs")
    sign_in_as @teacher

    remove outsider, as: :turbo_stream
    assert_response :not_found
    assert_no_match(/Zoé|Ailleurs/, response.body)
    assert_nil Orm::ClassroomStudent.find_by!(student: outsider).removed_at

    delete classroom_student_path("inconnue", @koffi.public_id), as: :turbo_stream
    assert_response :not_found
    assert_still_member
  end

  test "sans connexion, renvoi à la connexion" do
    remove

    assert_redirected_to new_session_path
    assert_still_member
  end
end
