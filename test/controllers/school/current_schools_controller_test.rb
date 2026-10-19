require "test_helper"

# ME-07 to ME-12 (ADR-0094 §4.2, UDR-0098): a teacher of two schools works in one current school at a time, chosen in
# the account panel and kept by the session; a teacher of one school sees nothing new.
class School::CurrentSchoolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @a = create_school(name: "Lycée moderne d'Abobo")
    @b = create_school(name: "Collège Saint-Michel")
    sixth = create_level(name: "6ème", position: 1)
    @a6 = create_classroom(school: @a, level: sixth, name: "6ème 1")
    @b6 = create_classroom(school: @b, level: sixth, name: "6ème 1")
    @b4 = create_classroom(school: @b, level: create_level(name: "4ème", position: 3), name: "4ème 2")
    @teacher = create_teacher(school: @a, classrooms: [ @a6, @b6 ], first_name: "Ibrahim", last_name: "Koné")
    Orm::TeacherSchool.create!(teacher: @teacher, school: @b, primary: false)
  end

  def switch_to(school) = patch teacher_current_school_path, params: { school_public_id: school.public_id }
  def t(key, **) = I18n.t(key, **)

  test "ME-08: the teacher switches to B, lands on their home with a toast, and the panel names B" do
    sign_in_as @teacher
    switch_to @b

    assert_redirected_to teacher_home_path
    assert_response :see_other
    follow_redirect!
    assert_select "#toasts", text: /#{Regexp.escape(t("school.current_schools.update.done", school: "Collège Saint-Michel"))}/
    assert_select "#current_school", text: /Collège Saint-Michel/
    assert_select "#account_schools button[aria-current=true][disabled]", count: 1
    assert_select "#account_schools button[aria-label='#{t('shared.navigation.account_panel.schools.current', school: 'Collège Saint-Michel')}']"
    assert_select "#account_schools button[aria-label=\"#{t('shared.navigation.account_panel.schools.switch', school: "Lycée moderne d'Abobo")}\"]"
  end

  test "ME-07: the home shows only the classrooms of the current school, homonyms apart" do
    sign_in_as @teacher
    get teacher_home_path
    assert_select "a[href='#{classroom_path(@a6.public_id)}']"
    assert_select "a[href='#{classroom_path(@b6.public_id)}']", count: 0

    switch_to @b
    get teacher_home_path

    assert_select "a[href='#{classroom_path(@b6.public_id)}']"
    assert_select "a[href='#{classroom_path(@a6.public_id)}']", count: 0
  end

  test "ME-09: a teacher of one school has no « Établissement » section and no « Changer » link" do
    sign_in_as create_teacher(school: @a, classrooms: [ @a6 ])
    get teacher_home_path

    assert_response :success
    assert_select "#account_schools", count: 0
    assert_select "#change_school", count: 0
    assert_select "a[href='#{teacher_schools_path}']", text: t("shared.navigation.account_panel.schools.link")
  end

  test "a school the teacher does not belong to, or an unknown one, is refused by a toast and nothing changes" do
    stranger = create_school
    sign_in_as @teacher

    [ { school_public_id: stranger.public_id }, { school_public_id: "inconnu" }, {} ].each do |params|
      patch(teacher_current_school_path, params:)
      assert_redirected_to teacher_home_path
      follow_redirect!
      assert_select "#toasts", text: /#{Regexp.escape(t("school.current_schools.update.refused"))}/
    end
    assert_equal [ nil ], Orm::Session.where(user_id: @teacher.id).pluck(:current_school_id)
  end

  test "ME-10: a session in B falls back on the primary school once B is gone, without an error" do
    sign_in_as @teacher
    switch_to @b
    follow_redirect!
    Orm::TeacherSchool.where(teacher: @teacher, school: @b).delete_all

    get teacher_home_path

    assert_response :success
    assert_select "#current_school", count: 0
    assert_select "a[href='#{classroom_path(@a6.public_id)}']"
    assert_no_match "Collège Saint-Michel", response.body
  end

  test "ME-11: each session keeps its own current school" do
    phone = open_session { it.sign_in_as @teacher }
    sign_in_as @teacher
    switch_to @b

    phone.get teacher_home_path

    assert_select phone.document_root_element, "#account_schools button[aria-current=true]", text: /Lycée moderne d'Abobo/
    assert_select phone.document_root_element, "a[href='#{classroom_path(@b6.public_id)}']", count: 0
    get teacher_home_path
    assert_select "#account_schools button[aria-current=true]", text: /Collège Saint-Michel/
  end

  # MET-4 (owner, 2026-10-16): each school is a self-contained space; a classroom of B does not open from A.
  test "ME-12: a classroom of B does not open from A: back home with what to do; declaring in B from A is refused" do
    sign_in_as @teacher
    get classroom_path(@b6.public_id)

    assert_redirected_to teacher_home_path
    assert_equal t("errors.codes.other_school"), flash[:alert]
    follow_redirect!
    assert_select "main", text: /Collège Saint-Michel/, count: 0

    post classroom_teaching_path(@b4.public_id), as: :turbo_stream
    assert_response :forbidden
    assert_match ERB::Util.html_escape(t("errors.codes.other_school")), response.body
    assert_not Orm::TeacherClassroom.exists?(teacher: @teacher, classroom: @b4)

    switch_to @b
    get classroom_path(@b6.public_id)
    assert_response :success
  end

  test "students, directions and the team cannot switch" do
    [ create_student(classroom: @a6), create_school_admin(school: @a), create_team_member ].each do |user|
      sign_in_as user
      switch_to @a
      assert_response :forbidden
      sign_out
    end
  end
end
