require "test_helper"

module Repositories
  module Catalog
    class ImportReportRepositoryTest < ActiveSupport::TestCase
      ImportError = Entities::Catalog::ImportError

      setup do
        @repository = ImportReportRepository.new
        @member = create_team_member(second_factor: false)
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def create_report(kind: "schools")
        @repository.create(kind:, checksum_sha256: "a" * 64, imported_by_id: @member.id, at: @at).value
      end

      test "crée un rapport en file, le retrouve par id et par public_id" do
        report = create_report

        assert_instance_of Entities::Catalog::ImportReport, report
        assert_equal [ "schools", "queued", 0, @member.id ], [ report.kind, report.status, report.total_count, report.imported_by_id ]
        assert report.running?
        assert_equal report, @repository.find(id: report.id)
        assert_equal report.id, @repository.find_by_public_id(public_id: report.public_id).id
        assert_nil @repository.find(id: 0)
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
      end

      test "un second rapport en cours du même type donne :conflict ; un autre type passe" do
        create_report

        result = @repository.create(kind: "schools", checksum_sha256: "b" * 64, imported_by_id: @member.id, at: @at)

        assert_equal :conflict, result.code
        assert_equal({ kind: [ :already_running ] }, result.errors)
        assert create_report(kind: "course_tree")
      end

      test "the generation of the classrooms has a report without a file; a second one running gives :conflict (ADR-0056)" do
        report = @repository.create(kind: "classrooms", checksum_sha256: nil, imported_by_id: @member.id, at: @at).value

        assert_equal [ "classrooms", "queued" ], [ report.kind, report.status ]
        assert_nil Orm::ImportReport.find(report.id).checksum_sha256
        assert_equal :conflict, @repository.create(kind: "classrooms", checksum_sha256: nil, imported_by_id: @member.id, at: @at).code
      end

      test "fail_stale passe failed les rapports commencés avant la limite, et eux seuls" do
        stale = create_import_report(kind: "schools", status: "importing", started_at: @at - 11.minutes)
        fresh = create_import_report(kind: "essentials", status: "validating", started_at: @at - 5.minutes)
        other = create_import_report(kind: "exercises", status: "importing", started_at: @at - 2.hours)

        assert_equal 1, @repository.fail_stale(kind: "schools", before: @at - 10.minutes, at: @at)
        assert_equal [ "failed", @at ], stale.reload.attributes.values_at("status", "finished_at")
        assert_equal "validating", fresh.reload.status
        assert_equal "importing", other.reload.status
        assert create_report
      end

      test "fail_stale passe aussi failed un rapport resté en file au-delà de la limite (job jamais pris)" do
        never_claimed = create_import_report(kind: "schools", status: "queued", created_at: @at - 11.minutes)
        waiting = create_import_report(kind: "essentials", status: "queued", created_at: @at - 5.minutes)

        assert_equal 1, @repository.fail_stale(kind: "schools", before: @at - 10.minutes, at: @at)
        assert_equal 0, @repository.fail_stale(kind: "essentials", before: @at - 10.minutes, at: @at)
        assert_equal [ "failed", @at ], never_claimed.reload.attributes.values_at("status", "finished_at")
        assert_equal "queued", waiting.reload.status
      end

      test "claim ne prend un rapport en file qu'une fois" do
        report = create_report

        assert @repository.claim(id: report.id, at: @at)
        assert_not @repository.claim(id: report.id, at: @at)
        assert_equal [ "validating", @at ], @repository.find(id: report.id).then { [ it.status, it.started_at ] }
      end

      test "advance pose statut et progression, et la version quand elle est connue" do
        report = create_report

        @repository.advance(id: report.id, status: "validating", processed_count: 100, format_version: 1)
        @repository.advance(id: report.id, status: "importing", processed_count: 200)

        found = @repository.find(id: report.id)

        assert_equal [ "importing", 200, 1 ], [ found.status, found.processed_count, found.format_version ]
      end

      test "finish pose le bilan et relit les erreurs en entités" do
        report = create_report
        counts = { total_count: 11, imported_count: 7, skipped_count: 2, error_count: 2 }
        errors = [ ImportError.new(path: "schools[3].name", code: "blank"),
                   ImportError.new(path: "schools[7].type", code: "invalid_value", params: { value: "lycée" }) ]

        assert @repository.finish(id: report.id, status: "completed", counts:, details: { "classrooms" => 77 }, errors:, at: @at)

        found = @repository.find(id: report.id)

        assert_equal [ "completed", 11, 7, 2, 2, @at ],
                     [ found.status, found.total_count, found.imported_count, found.skipped_count, found.error_count, found.finished_at ]
        assert_equal({ "classrooms" => 77 }, found.details)
        assert_equal errors, found.import_errors
        assert_not found.running?
      end

      test "finish tronque à 1 000 erreurs, error_count garde le vrai total" do
        report = create_report
        errors = Array.new(1_001) { |index| ImportError.new(path: "schools[#{index}].name", code: "blank") }
        counts = { total_count: 1_001, imported_count: 0, skipped_count: 0, error_count: 1_001 }

        @repository.finish(id: report.id, status: "completed", counts:, details: {}, errors:, at: @at)

        found = @repository.find(id: report.id)

        assert_equal 1_000, found.import_errors.size
        assert_equal 1_001, found.error_count
        assert_equal "schools[999].name", found.import_errors.last.path
      end
    end
  end
end
