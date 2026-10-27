require "test_helper"

# IL-15, IL-16, IL-17, IL-18 (ADR-0040, ADR-0085 §4.3, UDR-0081 §3.5): a signed-in student without an active classroom
# (archived, or removed) chooses one through the same cascade, the DRENA and the school of their last classroom already
# chosen and the levels already listed; the classroom they were removed from is refused by this way, only its link brings
# them back. A student in an active classroom is sent home, and refused in 403 on the form.
# UDR-0091 (CA-1, CA-2, CA-5): three numbered steps; the known school folded in one line with « Changer », the DRENA and
# school lists behind it; the levels as pills, the classrooms as boxes, all real radios; « Continuer » without JavaScript.
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

  test "UDR-0081 §3.5: « Choose your classroom », the DRENA and the school of the last classroom chosen, the levels listed" do
    sign_in_as @student

    get new_student_classroom_choice_path

    assert_response :success
    assert_select "h1", text: I18n.t("#{PAGE}.title")
    assert_equal "Choisis ta classe", I18n.t("#{PAGE}.title")
    # UDR-0091 §3.3 : plus de lien « Accueil » au-dessus du titre.
    assert_select "nav[aria-label='#{I18n.t('components.back_link.label')}']", 0
    assert_select "form#student-classroom-choice-form[action='#{student_classroom_choices_path}'][method=post]" \
                  "[data-controller='classroom--class-picker']" \
                  "[data-classroom--class-picker-schools-url-value='#{drena_schools_path('__drena__', scope: :student_classroom_choice)}']" \
                  "[data-classroom--class-picker-levels-url-value='#{school_picker_levels_path('__school__', scope: :student_classroom_choice)}']" \
                  "[data-classroom--class-picker-classrooms-url-value='" \
                  "#{school_picker_classrooms_path('__school__', '__level__', scope: :student_classroom_choice)}']" do
      assert_equal [ "1 #{I18n.t("#{PICKER}.step_school")}", "2 #{I18n.t("#{PICKER}.step_level")}",
                     "3 #{I18n.t("#{PICKER}.step_classroom")}" ], css_select("fieldset > legend").map { it.text.squish }
      # UDR-0091 §3.1 : l'établissement connu, replié en une ligne ; les deux listes derrière « Changer », toujours envoyées.
      assert_select "#class-picker-school-summary[data-classroom--class-picker-target=schoolSummary]", text: /Lycée Moderne de Cocody/ do
        assert_select "*", text: /Abidjan 1/
        assert_select "a[aria-label=?][data-action='classroom--class-picker#change']" \
                      "[href='#{new_student_classroom_choice_path(student_classroom_choice: { drena_public_id: @drena.public_id })}']",
                      I18n.t("#{PICKER}.change_label"), text: I18n.t("#{PICKER}.change")
      end
      assert_select "#class-picker-school-fields[hidden][data-classroom--class-picker-target=schoolFields]" do
        assert_select "select[name='student_classroom_choice[drena_public_id]'] option[selected][value='#{@drena.public_id}']"
        assert_select "turbo-frame#picker_schools select[name='student_classroom_choice[school_public_id]'] " \
                      "option[selected][value='#{@school.public_id}']", text: "Lycée Moderne de Cocody"
      end
      assert_select "turbo-frame#picker_levels input[type=radio][name='student_classroom_choice[level_slug]'][value='#{@level.slug}']"
      assert_select "turbo-frame#picker_levels label", text: "3ème"
      assert_select "turbo-frame#picker_levels input[checked]", 0
      assert_select "turbo-frame#picker_classrooms *", 0
      assert_select "turbo-frame#picker_classrooms + p", text: I18n.t("#{PICKER}.level_first")
      # Sans JavaScript, « Continuer » à chaque étape : la ligne repliée cache celui de l'établissement, pas celui du niveau.
      assert_select "noscript button[formmethod=get][formaction='#{new_student_classroom_choice_path}']", 2
      assert_select "#class-picker-step-level noscript button", text: I18n.t("#{PICKER}.continue")
      assert_select "button#student-classroom-choice-submit[type=submit][data-classroom--class-picker-target=submit]",
                    text: I18n.t("#{PAGE}.submit")
    end
    assert_equal "Rejoindre cette classe", I18n.t("#{PAGE}.submit")
    assert_select "[name*=full_name], [name*=pin], [name*=contact], [name*=code], #classroom-link-invalid", 0
  end

  test "without JavaScript: the choices sent in GET list the next step, over the last classroom" do
    sign_in_as @student

    get new_student_classroom_choice_path, params: { student_classroom_choice: choice_params(classroom_public_id: nil) }

    assert_select "turbo-frame#picker_levels input[type=radio][checked][value='#{@level.slug}']"
    assert_select "turbo-frame#picker_classrooms input[type=radio][name='student_classroom_choice[classroom_public_id]']", 2
    # UDR-0091 §3.6 : les radios vivent dans le fieldset de leur étape, qui les nomme.
    assert_select "fieldset#class-picker-step-level turbo-frame#picker_levels input[type=radio]", 1
    assert_select "fieldset#class-picker-step-classroom turbo-frame#picker_classrooms input[type=radio]", 2
    # Sans JavaScript, le bouton n'est jamais désactivé.
    assert_select "button#student-classroom-choice-submit:not([disabled])"

    # « Changer » sans JavaScript : la DRENA seule revient en GET, et les deux listes s'ouvrent, l'établissement à choisir.
    get new_student_classroom_choice_path, params: { student_classroom_choice: { drena_public_id: @drena.public_id } }

    assert_select "#class-picker-school-summary", 0
    assert_select "#class-picker-school-fields:not([hidden]) turbo-frame#picker_schools select"
    assert_select "turbo-frame#picker_schools option[selected]:not([value=''])", 0
    assert_select "turbo-frame#picker_levels *", 0
    assert_select "turbo-frame#picker_levels + p", text: I18n.t("#{PICKER}.school_first")
  end

  test "choices sent as a string instead of a hash are ignored: the last classroom's school stays chosen" do
    sign_in_as @student

    get new_student_classroom_choice_path, params: { student_classroom_choice: "x" }

    assert_response :success
    assert_select "turbo-frame#picker_levels input[type=radio][value='#{@level.slug}']"
  end

  test "a school sent with a DRENA it does not belong to, or without a DRENA, opens the lists: 200, no folded line" do
    sign_in_as @student
    other = create_drena(name: "Bouaké")

    [ { drena_public_id: other.public_id, school_public_id: @school.public_id },
      { school_public_id: @school.public_id, level_slug: @level.slug } ].each do |choices|
      get new_student_classroom_choice_path, params: { student_classroom_choice: choices }

      assert_response :success
      assert_select "#class-picker-school-summary", 0
      assert_select "#class-picker-school-fields:not([hidden])"
      assert_select "turbo-frame#picker_levels *", 0
    end
  end

  test "a student who never had a classroom starts from the DRENA" do
    sign_in_as create_student

    get new_student_classroom_choice_path

    assert_response :success
    assert_select "select[name='student_classroom_choice[drena_public_id]'] option[selected]", 0
    %w[picker_schools picker_levels picker_classrooms].each { assert_select "turbo-frame##{it} *", 0 }
    assert_select "#class-picker-school-summary", 0
    assert_select "#class-picker-school-fields:not([hidden])"
  end

  test "UDR-0081 §3.4: arriving from an invalid link, the alert once, in the student's words" do
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
    assert_select "turbo-frame#picker_levels input[type=radio][checked][value='#{@level.slug}']"

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

  # CA-D7 (partie serveur), ADR code-de-classe-a-six-caracteres §4.7 : « Choisis ta classe » accepte le code, sans la cascade.
  def join_by_code(code, **) = post(student_classroom_choices_path, params: { student_classroom_choice: { join_code: code, ** } })

  test "CA-D7: a student without a classroom enters the classroom of the code he types, way « code », and lands home, welcomed" do
    sign_in_as @student

    join_by_code "#{@other.reload.join_code[0, 3].upcase} #{@other.join_code[3, 3]}"

    assert_redirected_to student_home_path
    assert_response :see_other
    assert_equal I18n.t("classroom.student_classroom_choices.create.welcome"), flash[:notice]
    assert_equal [ [ @other.id, "code" ] ], open_memberships
  end

  test "CA-D7: the code needs neither the DRENA, the school, the level nor the classroom; the cascade sent with it is ignored" do
    sign_in_as @student

    join_by_code @other.reload.join_code, classroom_public_id: @removed_from.public_id, school_public_id: "autre"

    assert_redirected_to student_home_path
    assert_equal [ [ @other.id, "code" ] ], open_memberships
  end

  test "CA-B3: an unknown code, a malformed one and the code of an archived classroom are refused alike, in 422, nothing written" do
    archived = create_classroom(school: @school, level: @level, name: "3e 9", status: "archived")
    sign_in_as @student
    get new_student_classroom_choice_path # the sign-in toast is shown once, here
    refusals = [ "zzzzzz", "kfm37", archived.reload.join_code ].map do |code|
      join_by_code code
      assert_response :unprocessable_entity, code
      response.body.gsub(/value="[^"]*"/, "")
    end

    assert_equal 1, refusals.uniq.size
    assert_empty open_memberships
    assert I18n.exists?("#{ERRORS}.join_code.unknown")
  end

  # Lot D (accueil élève, état 6): the code typed on the home is refused on this page, with its field and its error under it.
  test "an unknown code comes back in 422 with the field filled and the error under it, linked to the field" do
    sign_in_as @student
    get new_student_classroom_choice_path

    join_by_code "zzzzzz"

    assert_response :unprocessable_entity
    # The code has its own small form and button, above the list, which has its own: choosing a class never resends the code.
    assert_select "form#student-classroom-code-form[action=?]", student_classroom_choices_path do
      assert_select "input[name='student_classroom_choice[join_code]'][value=zzzzzz][aria-invalid=true][required]"
      assert_select "button[type=submit]", text: I18n.t("classroom.student_homes.no_classroom.submit")
    end
    assert_select "form#student-classroom-choice-form input[name*=join_code]", 0
    assert_select "form#student-classroom-choice-form #student-classroom-choice-submit"
    assert_select "#student_classroom_choice_join_code_error", text: I18n.t("#{ERRORS}.join_code.unknown")
    assert_select "input[name='student_classroom_choice[join_code]'][aria-describedby~=student_classroom_choice_join_code_error]"
  end

  test "the list alone, with a valid classroom and no code, enters the classroom and lands home (after a refused code)" do
    sign_in_as @student
    join_by_code "zzzzzz"
    assert_response :unprocessable_entity

    choose

    assert_redirected_to student_home_path
    assert_equal [ [ @other.id, "standard" ] ], open_memberships
  end

  test "the classroom the student was removed from is refused by its code, in 403: only the link brings him back" do
    sign_in_as @student

    join_by_code @removed_from.reload.join_code

    assert_response :forbidden
    assert_select "[role=alert]", text: I18n.t("#{ERRORS}.base.removed_from_classroom")
    assert_empty open_memberships
  end

  test "a full classroom refuses the code in 403 with its reason" do
    @other.update!(max_students: 1)
    create_student(classroom: @other)
    sign_in_as @student

    join_by_code @other.reload.join_code

    assert_response :forbidden
    assert_select "[role=alert]", text: I18n.t("#{ERRORS}.base.classroom_full")
    assert_empty open_memberships
  end

  test "IL-18: a student in an active classroom is refused in 403 when he types a code, nothing changes" do
    student = create_student(classroom: @other)
    sign_in_as student

    join_by_code @removed_from.reload.join_code

    assert_response :forbidden
    assert_equal [ [ @other.id, "standard" ] ], open_memberships(student)
  end

  test "CA-B4: guessing codes while signed in is limited too: the 11th request of the minute is 429, shared with the check" do
    sign_in_as @student
    5.times { get classroom_code_path("zzzzzz") }
    5.times { join_by_code "zzzzzz" }

    join_by_code @other.reload.join_code

    assert_response :too_many_requests
    assert_select "[role=alert]", text: I18n.t("errors.codes.rate_limited")
    assert_empty open_memberships

    get classroom_code_path(@other.join_code)
    assert_response :too_many_requests
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

  test "a visitor is sent to sign in; a teacher, the direction and the team receive 403 (PRD §3)" do
    get new_student_classroom_choice_path

    assert_redirected_to new_session_path

    [ create_teacher, create_school_admin, create_team_member ].each do |user|
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
