require "test_helper"

# Lot A: the account of a school is created on the first write; « lost » without a reason is refused by the database.
class Repositories::Crm::AccountRepositoryTest < ActiveSupport::TestCase
  setup do
    @school = create_school
    @owner = create_team_member(team_role: "field")
    @repo = Repositories::Crm::AccountRepository.new
  end

  test "a school never followed has no account" do
    assert_nil @repo.find_by_school_id(school_id: @school.id)
  end

  test "save creates the row, then updates the same one" do
    at = Time.utc(2026, 11, 6, 9)
    account = Entities::Crm::Account.blank(@school.id).with(stage: "demo_done", owner_id: @owner.id, stage_changed_at: at)

    assert @repo.save(account:).success?
    saved = @repo.find_by_school_id(school_id: @school.id)
    assert_equal [ "demo_done", @owner.id, at ], [ saved.stage, saved.owner_id, saved.stage_changed_at ]

    @repo.save(account: saved.with(stage: "subscribed", owner_id: nil))
    assert_equal 1, Orm::CrmAccount.where(school_id: @school.id).count
    assert_equal [ "subscribed", nil ], @repo.find_by_school_id(school_id: @school.id).then { [ it.stage, it.owner_id ] }
  end

  test "R2: a concurrent first write (unique violation) is a conflict, not an exception" do
    raising = ->(*, **) { raise ActiveRecord::RecordNotUnique, "crm_accounts_school_id_key" }

    result = stub_any_instance(Orm::CrmAccount, :update!, raising) do
      @repo.save(account: Entities::Crm::Account.blank(@school.id).with(owner_id: @owner.id))
    end

    assert result.failure?
    assert_equal :conflict, result.code
  end

  test "a first write without a stage date stamps now" do
    @repo.save(account: Entities::Crm::Account.blank(@school.id).with(owner_id: @owner.id))

    assert_not_nil Orm::CrmAccount.find_by!(school_id: @school.id).stage_changed_at
  end

  test "lost without a reason is invalid and nothing is written" do
    result = @repo.save(account: Entities::Crm::Account.blank(@school.id).with(stage: "lost", lost_reason: nil))

    assert_equal :invalid, result.code
    assert_equal [ :blank ], result.errors[:lost_reason]
    assert_equal 0, Orm::CrmAccount.count
  end
end
