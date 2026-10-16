require "test_helper"

# ADR-0096 §4.4: the mass regeneration of the classroom links reads the active classrooms of the selected schools, and draws
# the tokens in the base in one UPDATE guarded against a link changed since the launch (RM-17, RM-19, RM-20).
module Repositories
  module Classroom
    class ClassroomRepositoryLinkRegenerationTest < ActiveSupport::TestCase
      setup do
        @repository = ClassroomRepository.new
        @drena = create_drena(name: "Abidjan 1")
        @school = create_school(drena: @drena, name: "Lycée Moderne de Cocody")
        @level = create_level
        @year = current_school_year
        @launch = Time.current
      end

      def selection(**) = Dtos::School::SchoolSelection.from(**)
      def classroom(school: @school, **) = create_classroom(school:, level: @level, **)

      def count(selection, school_year: @year, created_before: @launch + 1.minute)
        @repository.count_for_link_regeneration(selection:, school_year:, created_before:)
      end

      def batch(selection, school_year: @year, after_id: 0, limit: 10)
        @repository.link_regeneration_batch(selection:, school_year:, created_before: @launch + 1.minute, after_id:, limit:)
      end

      test "the active classrooms of the selected schools, of the year or of every year" do
        kept = classroom(name: "6e 1")
        classroom(name: "6e 2", status: "archived")
        old = classroom(name: "6e 3", school_year: current_school_year(on: 1.year.ago.to_date))
        elsewhere = classroom(school: create_school(drena: create_drena(name: "Bouaké")), name: "6e 1")

        assert_equal [ kept.id ], batch(selection(drena: @drena.public_id)).map(&:id)
        assert_equal [ kept.id, old.id ].sort, batch(selection(drena: @drena.public_id), school_year: nil).map(&:id).sort
        assert_equal 3, count(selection, school_year: nil)
        assert_equal 2, count(selection)
        assert_equal [ elsewhere.id ], batch(selection(school: elsewhere.school.public_id)).map(&:id)
        assert_equal 1, count(selection(school: @school.public_id))
      end

      test "the schools of the selection are the ones of the list" do
        classroom
        draft = create_school(drena: @drena, name: "Collège brouillon", status: "draft")
        classroom(school: draft)

        assert_equal 1, count(selection(status: "draft"))
        assert_equal 1, count(selection(search: "cocody"))
        assert_equal 2, count(selection(drena: @drena.public_id))
      end

      test "a candidate carries a label « school · classroom » and never its token" do
        record = classroom(name: "Tle D 1")

        candidate = batch(selection).sole

        assert_equal [ record.id, record.public_id, "Lycée Moderne de Cocody · Tle D 1", @school.id, nil ],
                     [ candidate.id, candidate.public_id, candidate.label, candidate.school_id, candidate.rotated_at ]
        refute_includes candidate.to_h.values, record.link_token
      end

      test "a classroom created after the launch is not part of it" do
        classroom
        late = classroom(created_at: @launch + 2.minutes)

        refute_includes batch(selection).map(&:id), late.id
      end

      test "rotate_link_tokens draws new distinct tokens in the base, with their date, and the old links die" do
        records = Array.new(3) { classroom(name: "6e #{it}") }
        old_tokens = records.map(&:link_token)

        written = @repository.rotate_link_tokens(ids: records.map(&:id), at: @launch, unchanged_since: @launch)

        assert_equal records.map(&:id).sort, written.sort
        fresh = records.map { it.reload.link_token }
        assert fresh.all? { it.match?(/\A[0-9a-f]{12}\z/) }
        assert_empty fresh & old_tokens
        assert_equal 3, fresh.uniq.size
        assert records.all? { (it.link_token_rotated_at - @launch).abs < 1 }
        old_tokens.each { assert_nil @repository.lock_by_link_token(token: it) }
      end

      test "RM-20: a link changed one by one since the launch is not changed again, nor an archived classroom" do
        changed = classroom(name: "6e 1")
        archived = classroom(name: "6e 2", status: "archived")
        @repository.rotate_link_token(id: changed.id)
        kept = [ changed.reload.link_token, archived.link_token ]

        written = @repository.rotate_link_tokens(ids: [ changed.id, archived.id ], at: @launch + 1.minute, unchanged_since: @launch - 1.second)

        assert_equal [], written
        assert_equal kept, [ changed.reload.link_token, archived.reload.link_token ]
      end

      test "rotate_link_token, the one by one gesture, now dates the change" do
        record = classroom

        @repository.rotate_link_token(id: record.id)

        assert_in_delta Time.current, record.reload.link_token_rotated_at, 5
      end

      test "an empty list writes nothing" do
        assert_equal [], @repository.rotate_link_tokens(ids: [], at: @launch, unchanged_since: @launch)
      end
    end
  end
end
