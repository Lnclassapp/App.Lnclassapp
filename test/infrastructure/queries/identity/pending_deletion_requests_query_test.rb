require "test_helper"

# ADR-0036, amendment (2): the pending deletion requests, nearest due date first, and their summary for the card of the
# team home. Processed and cancelled requests are gone from both.
class Queries::Identity::PendingDeletionRequestsQueryTest < ActiveSupport::TestCase
  setup do
    @admin = create_team_member
    @query = Queries::Identity::PendingDeletionRequestsQuery.new
  end

  def request_for(student, requested_on, status: "pending")
    closed = { closed_at: Time.current, closed_by: @admin } unless status == "pending"
    Orm::AccountDeletionRequest.create!(user: student, requested_on:, recorded_by: @admin, status:, **closed.to_h)
  end

  test "no pending request: an empty list and no summary" do
    request_for(create_student, Date.new(2026, 9, 1), status: "processed")
    request_for(create_student, Date.new(2026, 9, 2), status: "cancelled")

    assert_empty @query.call
    assert_nil @query.summary
  end

  test "the pending requests, nearest due date first, with the account to open" do
    awa = create_student(first_name: "Awa", last_name: "Koné", contact: "0100000001")
    yao = create_student(first_name: "Yao", last_name: "Brou", contact: "0100000002")
    request_for(awa, Date.new(2026, 9, 20))
    request_for(yao, Date.new(2026, 9, 3))
    request_for(create_student, Date.new(2026, 8, 1), status: "cancelled")

    rows = @query.call

    assert_equal [ Queries::Identity::PendingDeletionRequestsQuery::Row.new(public_id: yao.public_id, display_name: "Yao Brou",
                                                                           contact: "0100000002", requested_on: Date.new(2026, 9, 3)),
                   Queries::Identity::PendingDeletionRequestsQuery::Row.new(public_id: awa.public_id, display_name: "Awa Koné",
                                                                           contact: "0100000001", requested_on: Date.new(2026, 9, 20)) ], rows
    assert_equal [ Date.new(2026, 10, 3), Date.new(2026, 10, 20) ], rows.map(&:due_on)
    assert_equal %i[soon on_time], rows.map { it.stage(Date.new(2026, 9, 30)) }
  end

  test "the summary counts the pending requests and gives the nearest due date" do
    request_for(create_student, Date.new(2026, 9, 20))
    request_for(create_student, Date.new(2026, 9, 1))
    request_for(create_student, Date.new(2026, 8, 1), status: "processed")

    summary = @query.summary

    assert_equal [ 2, Date.new(2026, 9, 1), Date.new(2026, 10, 1) ], [ summary.count, summary.requested_on, summary.due_on ]
    assert_equal [ :on_time, :soon, :late ], [ Date.new(2026, 9, 25), Date.new(2026, 9, 26), Date.new(2026, 10, 2) ].map { summary.stage(it) }
  end
end
