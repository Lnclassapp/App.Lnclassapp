require "test_helper"

# Chantier cache-ecrans-lourds, lot 3 (ADR-0062 amended, ADR-0067): the trigram indexes serve the name searches only if
# their expressions stay identical to the ones of the queries. With sequential scans made prohibitive, the planner must
# pick every index of the OR: a query whose expression drifts from its index fails here instead of slowing down silently.
class TrigramSearchIndexesTest < ActiveSupport::TestCase
  test "the account search reads both name indexes" do
    plan = plan_of(Orm::User.where(Queries::Identity::AccountSearchQuery::NAMES, pattern: "%kou%"))

    assert_includes plan, "index_users_on_searchable_full_name"
    assert_includes plan, "index_users_on_searchable_reversed_name"
  end

  test "the school search reads the name and sigle indexes" do
    plan = plan_of(Orm::School.where(Queries::School::SchoolsQuery::SEARCHED, pattern: "%bouake%"))

    assert_includes plan, "index_schools_on_searchable_name"
    assert_includes plan, "index_schools_on_searchable_sigle"
  end

  # The national code is a plain column: no expression can drift. On an empty table the planner may prefer the partial
  # B-tree; at the production volume (≈ 3 900 schools) only the trigram index spares the scan of the whole OR.
  test "the pg_trgm extension is enabled and the national code has its trigram index" do
    connection = ActiveRecord::Base.connection

    assert_includes connection.extensions, "pg_trgm"
    assert_includes connection.indexes(:schools).map(&:name), "index_schools_on_national_code_trigram"
  end

  private

  def plan_of(scope)
    connection = ActiveRecord::Base.connection
    connection.execute("SET LOCAL enable_seqscan = off")
    connection.select_values("EXPLAIN #{scope.to_sql}").join("\n")
  end
end
