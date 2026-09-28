require "test_helper"
require Rails.root.join("db/migrate/20260928150000_create_referrals").to_s
require Rails.root.join("db/migrate/20260928150100_add_national_code_to_schools").to_s
require Rails.root.join("db/migrate/20260928150200_create_school_join_requests").to_s

# ADR-0063 (CP-01, CP-09): the growth tables arrive on a live database. Existing teachers each receive their own referral
# token; existing schools keep every column they had and receive no national code. Down then up, twice, outside any
# transaction: CREATE INDEX CONCURRENTLY refuses one.
class GrowthMigrationsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  MIGRATIONS = [ CreateReferrals, AddNationalCodeToSchools, CreateSchoolJoinRequests ].freeze

  def migrate(direction)
    order = direction == :down ? MIGRATIONS.reverse : MIGRATIONS
    ActiveRecord::Migration.suppress_messages { order.each { it.new.migrate(direction) } }
    [ Orm::TeacherProfile, Orm::School ].each(&:reset_column_information)
  end

  def school_rows = Orm::School.where(id: @school_ids).order(:id).pluck(:id, :name, :school_code, :status, :drena_id)

  teardown do
    Orm::TeacherSchool.where(teacher_id: @teacher_ids).delete_all
    Orm::TeacherProfile.where(user_id: @teacher_ids).delete_all
    Orm::User.where(id: @teacher_ids).delete_all
    Orm::School.where(id: @school_ids).delete_all
    Orm::Drena.where(id: @drena_ids).delete_all
    Orm::Material.where(id: @material_ids).delete_all
  end

  test "down then up gives every existing teacher a distinct token and leaves the schools untouched" do
    teachers = Array.new(3) { create_teacher }
    @teacher_ids = teachers.map(&:id)
    @school_ids = Orm::TeacherSchool.where(teacher_id: @teacher_ids).pluck(:school_id)
    @drena_ids = Orm::School.where(id: @school_ids).pluck(:drena_id)
    @material_ids = Orm::TeacherProfile.where(user_id: @teacher_ids).pluck(:material_id)
    before = school_rows

    migrate(:down)
    assert_not Orm::TeacherProfile.column_names.include?("referral_token")
    assert_not Orm::School.column_names.include?("national_code")
    assert_not ActiveRecord::Base.connection.table_exists?(:referrals)

    migrate(:up)
    tokens = Orm::TeacherProfile.where(user_id: @teacher_ids).pluck(:referral_token)
    assert_equal 3, tokens.uniq.size
    assert(tokens.all? { it.match?(/\A[0-9a-f]{12}\z/) }, tokens.inspect)
    assert_equal before, school_rows
    assert_equal [ nil ], Orm::School.where(id: @school_ids).distinct.pluck(:national_code)
    %i[referrals referral_shares school_join_requests].each { assert ActiveRecord::Base.connection.table_exists?(it), it }

    assert_no_changes -> { Orm::TeacherProfile.where(user_id: @teacher_ids).order(:id).pluck(:referral_token) } do
      ActiveRecord::Migration.suppress_messages { AddNationalCodeToSchools.new.migrate(:up) }
    end
  end
end
