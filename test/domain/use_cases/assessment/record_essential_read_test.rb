require "test_helper"

module UseCases
  module Assessment
    # ADR-0090 §4.1, CA-11 : seul l'élève laisse une lecture, sur une fiche qu'il a le droit de lire (la policy de lecture
    # est rejouée, ADR-0028) ; une panne du stockage est signalée et ne lève jamais.
    class RecordEssentialReadTest < ActiveSupport::TestCase
      Actor = Entities::Identity::Actor
      # The storage failure the delivery layer declares recoverable (ActiveRecord::ActiveRecordError in production).
      Unavailable = Class.new(StandardError)
      NOW = Time.utc(2026, 10, 15, 9, 30)
      Clock = Data.define(:now)
      Essential = Data.define(:id, :published) do
        def readable_chain_published? = published
      end

      class FakeReads
        include Ports::Assessment::EssentialReadRepositoryPort

        attr_reader :records

        def initialize(failure: nil)
          @failure = failure
          @records = []
        end

        def record(student_id:, essential_id:, at:)
          raise @failure if @failure

          @records << [ student_id, essential_id, at ]
          true
        end
      end

      class FakeReporter
        attr_reader :reports

        def initialize = @reports = []
        def report(error, **options) = @reports << [ error, options ]
      end

      setup do
        @reads = FakeReads.new
        @reporter = FakeReporter.new
      end

      def record(actor:, essential: Essential.new(id: 42, published: true), reads: @reads)
        RecordEssentialRead.new(reads:, policy: Policies::Catalog::ReadPublishedPolicy.new, reporter: @reporter,
                                recoverable: Unavailable, clock: Clock.new(now: NOW)).call(actor:, essential:)
      end

      test "CA-12: a student's opening is recorded, for this essential, at the clock's time" do
        result = record(actor: Actor.new(user_id: 7, role: :student))

        assert result.success?
        assert result.value
        assert_equal [ [ 7, 42, NOW ] ], @reads.records
      end

      test "CA-11: a teacher, a direction or a team member never leaves a read" do
        [ Actor.new(user_id: 2, role: :teacher), Actor.new(user_id: 3, role: :school_admin, school_id: 9),
          Actor.new(user_id: 4, role: :team, team_role: "content") ].each do |actor|
          result = record(actor:)

          assert result.success?, actor.role
          assert_not result.value, actor.role
        end

        assert_empty @reads.records
      end

      test "a sheet the student may not read (draft chain) is refused as not found, and nothing is recorded" do
        result = record(actor: Actor.new(user_id: 7, role: :student), essential: Essential.new(id: 42, published: false))

        assert_equal :not_found, result.code
        assert_empty @reads.records
      end

      test "a storage failure is reported with the essential and the student, and the read is not recorded" do
        failure = Unavailable.new("base indisponible")
        result = record(actor: Actor.new(user_id: 7, role: :student), reads: FakeReads.new(failure:))

        assert result.success?
        assert_not result.value
        assert_equal [ [ failure, { handled: true, context: { essential_id: 42, student_id: 7 } } ] ], @reporter.reports
      end

      test "any other error is a bug: it is raised, not reported" do
        reads = FakeReads.new(failure: ArgumentError.new("bogue"))

        assert_raises(ArgumentError) { record(actor: Actor.new(user_id: 7, role: :student), reads:) }
        assert_empty @reporter.reports
      end
    end
  end
end
