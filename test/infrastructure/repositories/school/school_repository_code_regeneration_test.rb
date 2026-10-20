require "test_helper"

# ADR-0096 §4.4, §4.5: the mass regeneration of the school codes reads the selection of the list and writes a batch in one
# UPDATE, guarded against a code changed since the launch.
module Repositories
  module School
    class SchoolRepositoryCodeRegenerationTest < ActiveSupport::TestCase
      setup do
        @repository = SchoolRepository.new
        @abidjan = create_drena(name: "Abidjan 1")
        @bouake = create_drena(name: "Bouaké")
        @launch = Time.current
      end

      def selection(**) = Dtos::School::SchoolSelection.from(**)
      def count(selection, created_before: @launch + 1.minute) = @repository.count_for_code_regeneration(selection:, created_before:)

      def batch(selection, after_id: 0, limit: 10, created_before: @launch + 1.minute)
        @repository.code_regeneration_batch(selection:, created_before:, after_id:, limit:)
      end

      test "the selection is exactly the one of the list, filter by filter" do
        lycee = create_school(drena: @abidjan, name: "Lycée Moderne de Cocody")
        create_school(drena: @abidjan, name: "Collège Saint Paul", school_type: "private", cycle: "first")
        create_school(drena: @abidjan, name: "Lycée en brouillon", status: "draft")
        create_school(drena: @bouake, name: "Lycée Moderne de Bouaké")
        query = Queries::School::SchoolsQuery.new
        filters = [ {}, { drena: @abidjan.public_id }, { school_type: "private" }, { cycle: "first" }, { status: "draft" },
                    { search: "moderne" }, { search: "MODERNE", drena: @abidjan.public_id }, { status: "unknown" } ]

        filters.each do |filter|
          assert_equal query.call(**filter).total_count, count(selection(**filter)), filter.inspect
        end
        assert_equal [ lycee.id ], batch(selection(search: "cocody")).map(&:id)
      end

      test "one school is the selection when it is given" do
        lycee = create_school(drena: @abidjan)
        create_school(drena: @abidjan)

        assert_equal 1, count(selection(school: lycee.public_id, drena: @bouake.public_id))
        assert_equal 0, count(selection(school: "inconnu"))
      end

      test "the batch goes by increasing id after the given one, with what the job needs and nothing secret" do
        schools = Array.new(3) { create_school(drena: @abidjan, name: "Lycée #{it}") }
        schools.first.update!(school_code_rotated_at: @launch - 1.day)

        first = batch(selection, limit: 2)
        second = batch(selection, after_id: first.last.id, limit: 2)

        assert_equal schools.map(&:id), (first + second).map(&:id)
        candidate = first.first
        assert_instance_of Entities::School::RegenerationCandidate, candidate
        assert_equal [ schools.first.public_id, "Lycée 0", schools.first.id ], [ candidate.public_id, candidate.label, candidate.school_id ]
        assert_in_delta @launch - 1.day, candidate.rotated_at, 1
        refute_includes candidate.to_h.values, schools.first.school_code
      end

      test "RM-14: a school created after the launch is not part of it" do
        create_school(drena: @abidjan)
        late = create_school(drena: @abidjan, created_at: @launch + 2.minutes)

        refute_includes batch(selection).map(&:id), late.id
        assert_equal 1, count(selection)
      end

      test "replace_school_codes writes the codes and their date in one statement, and returns the ids written" do
        a, b = Array.new(2) { create_school(drena: @abidjan) }

        written = @repository.replace_school_codes(rows: [ { id: a.id, school_code: "k7m4qz" }, { id: b.id, school_code: "xyz789" } ],
                                                   at: @launch, unchanged_since: @launch)

        assert_equal [ a.id, b.id ].sort, written.sort
        assert_equal [ "k7m4qz", "xyz789" ], [ a.reload.school_code, b.reload.school_code ]
        assert_in_delta @launch, a.school_code_rotated_at, 1
        assert_equal [], @repository.replace_school_codes(rows: [], at: @launch, unchanged_since: @launch)
      end

      test "RM-10: a code changed since the launch is not written again, an older change is" do
        changed = create_school(drena: @abidjan, school_code: "abc234", school_code_rotated_at: @launch + 1.second)
        older = create_school(drena: @abidjan, school_code: "abc345", school_code_rotated_at: @launch - 1.day)

        written = @repository.replace_school_codes(rows: [ { id: changed.id, school_code: "k7m4qz" }, { id: older.id, school_code: "xyz789" } ],
                                                   at: @launch + 1.minute, unchanged_since: @launch)

        assert_equal [ older.id ], written
        assert_equal [ "abc234", "xyz789" ], [ changed.reload.school_code, older.reload.school_code ]
      end

      test "RM-11: a code already taken raises the unique violation, and the transaction turns it into a conflict" do
        create_school(drena: @abidjan, school_code: "k7m4qz")
        other = create_school(drena: @abidjan, school_code: "abc234")

        result = Repositories::Shared::Transaction.new.attempt do
          @repository.replace_school_codes(rows: [ { id: other.id, school_code: "k7m4qz" } ], at: @launch, unchanged_since: @launch)
        end

        assert_equal :conflict, result.code
        assert_equal "abc234", other.reload.school_code
      end
    end
  end
end
