require "test_helper"

module Repositories
  module Assessment
    # ADR-0090 §4.1, CA-12 : une ligne par élève et par fiche, quel que soit le nombre d'ouvertures ; la première date
    # reste, la dernière avance.
    class EssentialReadRepositoryTest < ActiveSupport::TestCase
      setup do
        @student = create_student
        @essential = create_essential
        @repository = EssentialReadRepository.new
      end

      test "CA-12: three openings of the same essential leave one read, first_read_at kept, last_read_at the last one" do
        first = Time.zone.parse("2026-10-13 08:00")
        last = Time.zone.parse("2026-10-15 17:45")

        assert @repository.record(student_id: @student.id, essential_id: @essential.id, at: first)
        @repository.record(student_id: @student.id, essential_id: @essential.id, at: first + 1.day)
        @repository.record(student_id: @student.id, essential_id: @essential.id, at: last)

        reads = Orm::EssentialRead.where(student_id: @student.id)
        assert_equal 1, reads.count
        assert_equal [ first, last ], [ reads.first.first_read_at, reads.first.last_read_at ]
      end

      test "the reads of two students or of two essentials are separate rows" do
        other = create_student
        second = create_essential(course: @essential.course)
        at = Time.current

        @repository.record(student_id: @student.id, essential_id: @essential.id, at:)
        @repository.record(student_id: @student.id, essential_id: second.id, at:)
        @repository.record(student_id: other.id, essential_id: @essential.id, at:)

        assert_equal 3, Orm::EssentialRead.count
      end
    end
  end
end
