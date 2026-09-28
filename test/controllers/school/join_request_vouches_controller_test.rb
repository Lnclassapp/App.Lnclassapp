require "test_helper"

# CP-13 (ADR-0063, UDR-0050): an active teacher of the same school confirms a pending colleague from the home: the colleague
# is attached at once and the sponsor becomes their referrer. Anyone else is refused.
class School::JoinRequestVouchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @sponsor = create_teacher(school: @school, first_name: "Yao")
    @teacher = create_teacher(school: nil, first_name: "Awa", last_name: "Koné", material: create_material(name: "SVT", category: "science"))
    @join_request = create_join_request(school: @school, teacher: @teacher)
  end

  test "CP-13: the home of an active colleague lists the pending request with « Je confirme », without the number" do
    sign_in_as @sponsor

    get teacher_home_path

    assert_select "#pending_colleagues li#join_request_#{@join_request.public_id}" do
      assert_select "*", text: /Awa Koné/
      assert_select "*", text: /SVT/
      assert_select "form[action='#{join_request_vouch_path(@join_request.public_id)}'] button", text: /#{I18n.t("classroom.teacher_homes.pending_colleagues.vouch")}/
    end
    assert_no_match(/#{@teacher.contact}/, response.body)
  end

  test "CP-13: « Je confirme » attaches the colleague, makes the sponsor their referrer, and removes the line in Turbo Stream" do
    sign_in_as @sponsor

    post join_request_vouch_path(@join_request.public_id), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=remove][target=pending_colleagues]"
    assert_select "turbo-stream[action=append][target=toasts]",
                  text: /#{Regexp.escape(I18n.t("school.join_request_vouches.create.done", name: "Awa Koné"))}/
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher: @teacher).pluck(:school_id)
    assert_equal [ [ @sponsor.id, "sponsor" ] ], Orm::Referral.where(referee: @teacher).pluck(:referrer_id, :source)
    assert_equal [ "approved", "sponsor", @sponsor.id ], @join_request.reload.values_at(:status, :decided_via, :decided_by_id)
  end

  test "with another pending colleague left, only the line goes; without Turbo, back to the home" do
    other = create_join_request(school: @school)
    sign_in_as @sponsor

    post join_request_vouch_path(@join_request.public_id), as: :turbo_stream
    assert_select "turbo-stream[action=remove][target=join_request_#{@join_request.public_id}]"

    post join_request_vouch_path(other.public_id)
    assert_redirected_to teacher_home_path
    assert_equal I18n.t("school.join_request_vouches.create.done", name: "Awa Koné"), flash[:notice]
  end

  test "a teacher of another school, the team and a student are refused; nothing changes" do
    team = create_team_member
    [ create_teacher, team, create_student(classroom: create_classroom(school: @school)) ].each do |user|
      sign_in_as user
      post join_request_vouch_path(@join_request.public_id), as: :turbo_stream

      assert_response :forbidden
      sign_out
    end
    assert_equal "pending", @join_request.reload.status
  end

  test "a request already decided: a toast says so" do
    @join_request.update_columns(status: "approved", decided_at: Time.current, decided_via: "team")
    sign_in_as @sponsor

    post join_request_vouch_path(@join_request.public_id), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t("school.join_request_vouches.create.already_decided")}/
  end

  test "an unknown request: 404" do
    sign_in_as @sponsor

    post join_request_vouch_path("inconnue")

    assert_response :not_found
  end
end
