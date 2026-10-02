require "test_helper"

module Repositories
  module Identity
    # ADR-0036, amendment (2): the deletion requests on a real database. One pending request per account, closed once
    # (processed or cancelled) by whoever handled it; nothing is ever deleted.
    class DeletionRequestRepositoryTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 2, 10)

      setup do
        @repository = DeletionRequestRepository.new
        @admin = create_team_member
        @student = create_student
      end

      def record(user: @student, requested_on: Date.new(2026, 9, 20))
        @repository.record(user_id: user.id, requested_on:, recorded_by_id: @admin.id, at: NOW)
      end

      test "records a pending request with its date of reception and its author, read back as pending" do
        recorded = record

        assert recorded.success?
        assert_equal Entities::Identity::DeletionRequest.new(id: recorded.value.id, user_id: @student.id,
                                                             requested_on: Date.new(2026, 9, 20), status: "pending"), recorded.value
        assert_equal recorded.value, @repository.pending_for(user_id: @student.id)
        row = Orm::AccountDeletionRequest.find(recorded.value.id)
        assert_equal [ @admin.id, nil, nil, NOW ], [ row.recorded_by_id, row.closed_at, row.closed_by_id, row.created_at ]
        assert_nil @repository.pending_for(user_id: create_student.id)
      end

      test "a second pending request for the same account is a conflict, without breaking the surrounding transaction" do
        record

        ActiveRecord::Base.transaction do
          assert_equal [ :conflict, { base: [ :already_pending ] } ], record.then { [ it.code, it.errors ] }
          assert record(user: create_student).success?
        end
        assert_equal 1, Orm::AccountDeletionRequest.where(user_id: @student.id).count
      end

      test "closes the pending request once, by whom and when; a new request may follow" do
        pending = record.value
        other = create_team_member

        closed = @repository.close(user_id: @student.id, status: "cancelled", closed_by_id: other.id, at: NOW + 60)

        assert_equal pending.with(status: "cancelled"), closed
        assert_equal [ "cancelled", NOW + 60, other.id ], Orm::AccountDeletionRequest.find(pending.id).then { [ it.status, it.closed_at, it.closed_by_id ] }
        assert_nil @repository.pending_for(user_id: @student.id)
        assert_nil @repository.close(user_id: @student.id, status: "processed", closed_by_id: other.id, at: NOW)
        assert record(requested_on: Date.new(2026, 10, 1)).success?
        assert_equal "processed", @repository.close(user_id: @student.id, status: "processed", closed_by_id: @admin.id, at: NOW).status
        assert_equal %w[cancelled processed], Orm::AccountDeletionRequest.where(user_id: @student.id).order(:id).pluck(:status)
      end

      test "the database refuses an unknown status, a closed request without date or author, and a pending one with them" do
        base = { user_id: @student.id, requested_on: Date.new(2026, 9, 20), recorded_by_id: @admin.id }
        [ { status: "deleted" }, { status: "processed" }, { status: "processed", closed_at: NOW },
          { status: "pending", closed_at: NOW, closed_by_id: @admin.id } ].each do |attributes|
          assert_raises(ActiveRecord::CheckViolation, attributes.inspect) do
            ActiveRecord::Base.transaction(requires_new: true) { Orm::AccountDeletionRequest.create!(**base, **attributes) }
          end
        end
      end

      test "the request keeps its account and the people who acted on it (RESTRICT)" do
        pending = record.value
        @repository.close(user_id: @student.id, status: "cancelled", closed_by_id: @admin.id, at: NOW)

        [ @student, @admin ].each do |user|
          assert_raises(ActiveRecord::InvalidForeignKey) do
            ActiveRecord::Base.transaction(requires_new: true) { Orm::User.where(id: user.id).delete_all }
          end
        end
        assert Orm::AccountDeletionRequest.exists?(pending.id)
      end
    end
  end
end
