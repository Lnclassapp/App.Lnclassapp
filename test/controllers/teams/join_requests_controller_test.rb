require "test_helper"

# CP-12 (ADR-0063, UDR-0050): on a school's page, the team validates or refuses the teachers who signed up without code;
# each decision is audited. Nobody else may decide.
class Teams::JoinRequestsControllerTest < ActionDispatch::IntegrationTest
  SCOPE = "teams.join_requests".freeze

  setup do
    @member = create_team_member
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @svt = create_material(name: "SVT", category: "science")
    @teacher = create_teacher(school: nil, material: @svt, first_name: "Awa", last_name: "Koné", contact: "0501020304")
    @join_request = create_join_request(school: @school, teacher: @teacher)
  end

  def decide(decision, request: @join_request) = patch school_join_request_path(@school.public_id, request.public_id), params: { decision: }

  test "CP-12: the school page lists the pending teachers, with their number, « Valider » and « Refuser » confirmed" do
    sign_in_as @member

    get school_path(@school.public_id)

    assert_select "section#school_join_requests li#join_request_#{@join_request.public_id}" do
      assert_select "*", text: /Awa Koné/
      assert_select "*", text: /05 01 02 03 04/
      assert_select "*", text: /SVT/
      assert_select "form[action='#{school_join_request_path(@school.public_id, @join_request.public_id)}'] input[name=decision][value=approve]"
      assert_select "dialog#reject-join-request-#{@join_request.public_id} form input[name=decision][value=reject]"
    end
  end

  test "a school without pending request has no such section" do
    @join_request.update_columns(status: "rejected", decided_at: Time.current, decided_via: "team")
    sign_in_as @member

    get school_path(@school.public_id)

    assert_select "#school_join_requests", 0
  end

  test "CP-12: « Valider » attaches the teacher, audited, and leads back to the school page" do
    sign_in_as @member

    decide("approve")

    assert_redirected_to school_path(@school.public_id)
    assert_response :see_other
    assert_equal I18n.t("#{SCOPE}.update.approved", name: "Awa Koné"), flash[:notice]
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher: @teacher).pluck(:school_id, :primary)
    assert_equal [ "approved", @member.id, "team" ], @join_request.reload.values_at(:status, :decided_by_id, :decided_via)
    event = Orm::AuditEvent.sole
    assert_equal [ "school.changed", "join_request_approved" ], [ event.action, event.metadata["change"] ]
  end

  test "CP-12: « Refuser » refuses, audited; a second decision says it is already done" do
    sign_in_as @member

    decide("reject")
    assert_equal I18n.t("#{SCOPE}.update.rejected", name: "Awa Koné"), flash[:notice]
    assert_equal "rejected", @join_request.reload.status

    decide("approve")
    assert_redirected_to school_path(@school.public_id)
    assert_equal I18n.t("#{SCOPE}.update.already_decided"), flash[:alert]
    assert_equal 0, Orm::TeacherSchool.where(teacher: @teacher).count
  end

  test "an unknown request is not found; an unknown decision is refused" do
    sign_in_as @member

    patch school_join_request_path(@school.public_id, "inconnue"), params: { decision: "approve" }
    assert_response :not_found
    decide("maybe")
    assert_response :unprocessable_entity
    assert_equal "pending", @join_request.reload.status
  end

  test "m3: a request decided through the URL of another school is not found, and stays pending" do
    sign_in_as @member

    patch school_join_request_path(create_school.public_id, @join_request.public_id), params: { decision: "approve" }

    assert_response :not_found
    assert_equal "pending", @join_request.reload.status
  end

  test "a teacher of the school and a student are refused in 403" do
    [ create_teacher(school: @school), create_student(classroom: create_classroom(school: @school)) ].each do |user|
      sign_in_as user
      decide("approve")

      assert_response :forbidden
      sign_out
    end
    assert_equal "pending", @join_request.reload.status
  end
end
