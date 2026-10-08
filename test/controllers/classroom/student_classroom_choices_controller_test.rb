require "test_helper"

# IL-15, IL-16, IL-17, IL-18 (ADR-0040, ADR-0083 §4.3, UDR-0079 §3.5): a signed-in student without an active classroom
# (archived, or removed) chooses one through the same cascade, the DRENA and the school of their last classroom already
# chosen and the levels already listed; the classroom they were removed from is refused by this way, only its link brings
# them back. A student in an active classroom is sent home, and refused in 403 on the form.
class Classroom::StudentClassroomChoicesControllerTest < ActionDispatch::IntegrationTest
  ERRORS = "activemodel.errors.models.dtos/classroom/student_registration_input.attributes".freeze
  PAGE = "classroom.student_classroom_choices.new".freeze
  PICKER = "classroom.student_registrations.class_picker".freeze

  setup do
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Moderne de Cocody")
    @level = create_level(name: "3ème")
    @removed_from = create_classroom(school: @school, level: @level, name: "3e 2")
    @other = create_classroom(school: @school, level: @level, name: "3e 3")
    @student = create_student(classroom: @removed_from, joined_at: 30.days.ago)
    remove(@student, @removed_from)
  end

  def remove(student, classroom, at: 1.day.ago)
    Orm::ClassroomStudent.where(student:, classroom:).update_all(left_at: at, removed_at: at, removed_by_id: create_teacher.id)
  end

  def choice_params(classroom = @other, **overrides)
    { drena_public_id: @drena.public_id, school_public_id: @school.public_id, level_slug: @level.slug,
      classroom_public_id: classroom.public_id, **overrides }
  end

  def choose(classroom = @other, **) = post(student_classroom_choices_path, params: { student_classroom_choice: choice_params(classroom, **) })
  def open_memberships(student = @student) = Orm::ClassroomStudent.where(student:, left_at: nil).pluck(:classroom_id, :joined_via)

  test "UDR-0079 §3.5: « Choose your classroom », the DRENA and the school of the last classroom chosen, the levels listed" do
    sign_in_as @student

    get new_student_classroom_choice_path

    assert_response :success
    assert_select "h1", text: I18n.t("#{PAGE}.title")
    assert_equal "Choisis ta classe", I18n.t("#{PAGE}.title")
    assert_select "form#student-classroom-choice-form[action='#{student_classroom_choices_path}'][method=post]" \
                  "[data-controller='classroom--class-picker']" \
                  "[data-classroom--class-picker-schools-url-value='#{drena_schools_path('__drena__', scope: :student_classroom_choice)}']" \
                  "[data-classroom--class-picker-levels-url-value='#{school_picker_levels_path('__school__', scope: :student_classroom_choice)}']" \
                  "[data-classroom--class-picker-classrooms-url-value='" \
                  "#{school_picker_classrooms_path('__school__', '__level__', scope: :student_classroom_choice)}']" do
      assert_select "select[name='student_classroom_choice[drena_public_id]'] option[selected][value='#{@drena.public_id}']"
      assert_select "turbo-frame#picker_schools select[name='student_classroom_choice[school_public_id]'] " \
                    "option[selected][value='#{@school.public_id}']", text: "Lycée Moderne de Cocody"
      assert_select "turbo-frame#picker_levels select[name='student_classroom_choice[level_slug]'] option[value='#{@level.slug}']",
                    text: "3ème"
      assert_select "turbo-frame#picker_levels option[selected][value]", 0
      assert_select "turbo-frame#picker_classrooms *", 0
      assert_select "noscript button[formmethod=get][formaction='#{new_student_classroom_choice_path}']", text: I18n.t("#{PICKER}.continue")
      assert_select "button#student-classroom-choice-submit[type=submit][data-classroom--class-picker-target=submit]",
                    text: I18n.t("#{PAGE}.submit")
    end
    assert_equal "Rejoindre cette classe", I18n.t("#{PAGE}.submit")
    assert_select "[name*=full_name], [name*=pin], [name*=contact], [name*=code], #classroom-link-invalid", 0
  end

  test "without JavaScript: the choices sent in GET list the next step, over the last classroom" do
    sign_in_as @student

    get new_student_classroom_choice_path, params: { student_classroom_choice: choice_params(classroom_public_id: nil) }

    assert_select "turbo-frame#picker_levels option[selected][value='#{@level.slug}']"
    assert_select "turbo-frame#picker_classrooms input[type=radio][name='student_classroom_choice[classroom_public_id]']", 2
  end

  test "a student who never had a classroom starts from the DRENA" do
    sign_in_as create_student

    get new_student_classroom_choice_path

    assert_response :success
    assert_select "select[name='student_classroom_choice[drena_public_id]'] option[selected]", 0
    %w[picker_schools picker_levels picker_classrooms].each { assert_select "turbo-frame##{it} *", 0 }
  end

  test "UDR-0079 §3.4: arriving from an invalid link, the alert once, in the student's words" do
    sign_in_as @student

    get join_classroom_path("cccccccccccc")
    follow_redirect!

    assert_select "#classroom-link-invalid[role=alert]", text: "Ce lien n'est plus valable. Choisis ta classe."

    get new_student_classroom_choice_path

    assert_select "#classroom-link-invalid", 0
  end

  test "IL-15: the classroom the student was removed from is refused in 403, with the neutral alert at the top" do
    sign_in_as @student

    choose(@removed_from)

    assert_response :forbidden
    assert_select "[role=alert]", text: "Tu ne peux pas rejoindre cette classe. Demande son lien à ton enseignant."
    assert_select "turbo-frame#picker_classrooms input[checked][value='#{@removed_from.public_id}']"
    assert_empty open_memberships
  end

  test "IL-15: another classroom becomes the primary one, way « standard », and the student lands home, welcomed" do
    sign_in_as @student

    choose(@other)

    assert_redirected_to student_home_path
    assert_response :see_other
    assert_equal I18n.t("classroom.student_classroom_choices.create.welcome"), flash[:notice]
    assert_equal [ [ @other.id, "standard" ] ], open_memberships
  end

  test "IL-16: back by the link, then removed a second time, the standard way refuses the classroom again" do
    sign_in_as @student

    post join_classroom_path(@removed_from.reload.link_token)

    assert_equal [ [ @removed_from.id, "link" ] ], open_memberships

    remove(@student, @removed_from, at: Time.current)
    choose(@removed_from)

    assert_response :forbidden
    assert_empty open_memberships
  end

  test "IL-17: a student whose classroom is archived chooses a new one, without a new account; the old one is closed" do
    archived = create_classroom(school: @school, level: @level, name: "3e 1", status: "archived")
    student = create_student(classroom: archived)
    sign_in_as student

    get new_student_classroom_choice_path

    assert_select "turbo-frame#picker_schools option[selected][value='#{@school.public_id}']"

    assert_no_difference -> { Orm::User.count } do
      choose(@other)
    end

    assert_redirected_to student_home_path
    assert_equal [ [ @other.id, "standard" ] ], open_memberships(student)
    assert_not_nil Orm::ClassroomStudent.find_by!(student:, classroom: archived).left_at
  end

  test "a classroom outside the cascade, or none, is refused in 422 under the classroom, the choices kept" do
    sign_in_as @student
    archived = create_classroom(school: @school, level: @level, name: "3e 9", status: "archived")

    choose(archived)

    assert_response :unprocessable_entity
    assert_select "#student_classroom_choice_classroom_public_id_error", text: I18n.t("#{ERRORS}.classroom_public_id.unavailable")
    assert_select "turbo-frame#picker_levels option[selected][value='#{@level.slug}']"

    choose(classroom_public_id: nil)

    assert_response :unprocessable_entity
    assert_select "#student_classroom_choice_classroom_public_id_error", text: I18n.t("#{ERRORS}.classroom_public_id.blank")
    assert_empty open_memberships
  end

  test "a full classroom sent anyway is refused in 403 with its reason" do
    @other.update!(max_students: 1)
    create_student(classroom: @other)
    sign_in_as @student

    choose(@other)

    assert_response :forbidden
    assert_select "[role=alert]", text: I18n.t("#{ERRORS}.base.classroom_full")
    assert_empty open_memberships
  end

  test "IL-18: a student in an active classroom is sent home from the page; a POST is refused in 403 with the reason" do
    student = create_student(classroom: @other)
    sign_in_as student

    get new_student_classroom_choice_path

    assert_redirected_to student_home_path

    choose(@removed_from)

    assert_response :forbidden
    assert_select "[role=alert]", text: "Tu es déjà inscrit dans une classe."
    assert_equal [ [ @other.id, "standard" ] ], open_memberships(student)
  end

  test "a visitor is sent to sign in; a teacher and the team receive 403" do
    get new_student_classroom_choice_path

    assert_redirected_to new_session_path

    [ create_teacher, create_team_member ].each do |user|
      sign_in_as user

      get new_student_classroom_choice_path
      assert_response :forbidden

      choose(@other)
      assert_response :forbidden
      sign_out
    end
    assert_empty Orm::ClassroomStudent.where(classroom: @other)
  end
end
