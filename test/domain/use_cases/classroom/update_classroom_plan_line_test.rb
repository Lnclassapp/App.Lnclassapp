require "test_helper"
require_relative "../../../support/domain/taxonomy_fixture"
require_relative "../../../support/domain/fake_classroom_plan"

# BC-02, BC-03, BC-08, ADR-0058: the team changes the two counts of one line of the barème; each changed count is
# written and journaled, nothing else.
module UseCases
  module Classroom
    class UpdateClassroomPlanLineTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 12)
      Clock = Data.define(:now)
      Fixture = Entities::Catalog::TaxonomyFixture
      Entry = Entities::Classroom::ClassroomPlan::Entry

      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        def initialize(lookup) = @lookup = lookup
        def lookup = @lookup
      end

      class FakeAuditLog
        include Ports::Identity::AuditLogPort

        attr_reader :records

        def initialize = @records = []
        def record(**entry) = (@records << entry) && true
      end

      setup do
        @lookup = Fixture.lookup(pairs: Fixture::PAIRS.merge("tle" => %w[a a1 a2 c d]))
        @plan = FakeClassroomPlan.new(Fixture.plan(@lookup))
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def update(level_slug: "6eme", series_slug: nil, public_count: "4", private_count: "2", actor: @team)
        dto = Dtos::Classroom::ClassroomPlanLineInput.new(public_count:, private_count:)
        UpdateClassroomPlanLine.new(classroom_plan: @plan, taxonomy: FakeTaxonomy.new(@lookup), audit_log: @audit_log,
                                    transaction: @transaction, policy: Policies::Classroom::ManageClassroomPlanPolicy.new,
                                    clock: Clock.new(NOW))
                               .call(actor:, level_slug:, series_slug:, dto:)
      end

      def count(school_type, level_id, series_id = nil) = @plan.plan.count(school_type:, level_id:, series_id:)

      test "a changed count is written and journaled, the unchanged one is neither" do
        result = update(public_count: "5", private_count: "2")

        assert result.success?
        assert_equal "6ème", result.value.name
        assert_equal({ "public" => 5, "private" => 2 }, result.value.counts)
        assert_equal [ 5, 2 ], [ count("public", 1), count("private", 1) ]
        assert_equal [ [ Entry.new(school_type: "public", level_id: 1, series_id: nil, count: 5) ] ], @plan.saves
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "classroom_plan.changed", actor_id: 7, at: NOW, subject_type: "Level", subject_id: 1,
                         metadata: { school_type: "public", level: "6eme", series: nil, from: 4, to: 5, source: "manual" } } ], @audit_log.records
      end

      test "a pair of the second cycle, undefined until now, gets its two counts, each journaled from nil" do
        result = update(level_slug: "tle", series_slug: "a", public_count: "3", private_count: "0")

        assert result.success?
        assert_equal "Tle A", result.value.name
        assert_equal [ 3, 0 ], [ count("public", 7, 101), count("private", 7, 101) ]
        assert_equal [ [ "public", nil, 3 ], [ "private", nil, 0 ] ],
                     @audit_log.records.map { it[:metadata].values_at(:school_type, :from, :to) }
        assert_equal [ "a" ], @audit_log.records.map { it[:metadata][:series] }.uniq
      end

      test "the same counts again: success, nothing written, nothing journaled" do
        result = update(level_slug: "tle", series_slug: "d", public_count: "6", private_count: "3")

        assert result.success?
        assert_empty @plan.saves
        assert_empty @audit_log.records
        assert_equal 0, @transaction.calls
      end

      test "an invalid count is refused, nothing written" do
        result = update(public_count: "31", private_count: "")

        assert_equal :invalid, result.code
        assert_equal %i[private_count public_count], result.errors.keys.sort
        assert_empty @plan.saves
      end

      test "an unknown line is not found: unknown level or series, unlinked pair, series on the first cycle, none on the second" do
        [ { level_slug: "terminale" }, { level_slug: "tle", series_slug: "b" }, { level_slug: "2nde", series_slug: "d" },
          { level_slug: "6eme", series_slug: "a" }, { level_slug: "tle" } ].each do |line|
          assert_equal :not_found, update(**line).code, line.inspect
        end
        assert_empty @plan.saves
      end

      test "only the team, checked first" do
        teacher = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id: 1)

        assert_equal :forbidden, update(actor: teacher).code
        assert_equal :forbidden, update(level_slug: "inconnu", actor: nil).code
        assert_empty @plan.saves
        assert_empty @audit_log.records
      end
    end
  end
end
