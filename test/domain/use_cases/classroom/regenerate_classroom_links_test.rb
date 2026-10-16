require "test_helper"
require_relative "../../../support/domain/fake_regeneration"

# ADR-0096 §4.3, RM-17, RM-19, RM-20, RM-23: the mass regeneration of the classroom links, on simulated ports — the tokens
# are drawn by the base, the year of the report is read, the audit names the school of each classroom and never a token.
module UseCases
  module Classroom
    class RegenerateClassroomLinksTest < ActiveSupport::TestCase
      Fake = FakeRegeneration
      LAUNCH = Fake::LAUNCH

      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        attr_reader :rotated, :batches

        def initialize(candidates, refused: [])
          @candidates = candidates
          @refused = refused
          @rotated = []
          @batches = []
        end

        def link_regeneration_batch(selection:, school_year:, created_before:, after_id:, limit:)
          @batches << [ selection.to_h, school_year, created_before ]
          @candidates.select { it.id > after_id }.first(limit)
        end

        def rotate_link_tokens(ids:, at:, unchanged_since:)
          raise FakeTransaction::Refused if ids.size > 1 && ids.intersect?(@refused)

          @rotated.concat(ids)
          ids
        end
      end

      setup do
        details = { "selection" => { "school" => "lycee42", "school_year" => "2026-2027" }, "expected_count" => 2 }
        @reports = Fake::Reports.new(kind: "classroom_links", details:)
        @audit = Fake::AuditLog.new
      end

      def regenerate(candidates, **)
        @classrooms = FakeClassrooms.new(candidates, **)
        RegenerateClassroomLinks.new(classrooms: @classrooms, reports: @reports, users: Fake::Users.new(Fake::ADMIN), audit_log: @audit,
                                     transaction: FakeTransaction.new, policy: Policies::School::RegenerateCodesInBulkPolicy.new,
                                     clock: Fake::Clock.new(LAUNCH + 1.minute))
                                .call(report_id: 1)
      end

      def classrooms = [ Fake.candidate(10, "Lycée · 6e 1", school_id: 4), Fake.candidate(11, "Lycée · 6e 2", school_id: 4) ]

      test "RM-17, RM-19: the classrooms of the selection and of the year of the report have their link changed" do
        assert regenerate(classrooms).success?

        assert_equal [ 10, 11 ], @classrooms.rotated
        assert_equal [ { "school" => "lycee42" }, "2026-2027", LAUNCH ], @classrooms.batches.first
        assert_equal({ total_count: 2, imported_count: 2, skipped_count: 0, error_count: 0 }, @reports.finished[:counts])
      end

      test "RM-23: one audit line per classroom, on its school, with the report and never a token" do
        regenerate(classrooms)

        assert_equal [ { action: "school.changed", actor_id: 7, at: LAUNCH + 1.minute, subject_type: "School", subject_id: 4,
                         metadata: { change: "classroom_link_changed", classroom_public_id: "p10", report_public_id: "rapport1" } },
                       { action: "school.changed", actor_id: 7, at: LAUNCH + 1.minute, subject_type: "School", subject_id: 4,
                         metadata: { change: "classroom_link_changed", classroom_public_id: "p11", report_public_id: "rapport1" } } ],
                     @audit.many
      end

      test "RM-20: a link changed one by one since the launch is not changed again" do
        regenerate([ Fake.candidate(10, "Lycée · 6e 1", school_id: 4, rotated_at: LAUNCH + 1.second), classrooms.last ])

        assert_equal [ 11 ], @classrooms.rotated
        assert_equal 1, @reports.finished[:counts][:skipped_count]
      end

      test "RM-24: a batch refused by the unique index of the tokens is replayed classroom by classroom" do
        regenerate(classrooms, refused: [ 11 ])

        assert_equal [ 10, 11 ], @classrooms.rotated
        assert_equal 2, @reports.finished[:counts][:imported_count]
      end
    end
  end
end
