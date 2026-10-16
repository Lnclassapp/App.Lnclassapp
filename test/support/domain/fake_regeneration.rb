# In-memory ports of a mass regeneration (ADR-0096): one report claimed or resumed, the author, the batched audit.
module FakeRegeneration
  LAUNCH = Time.utc(2026, 10, 16, 12)
  Clock = Data.define(:now)

  class Reports
    include Ports::Catalog::ImportReportRepositoryPort

    attr_reader :report, :advances, :finished

    def initialize(kind:, status: "queued", details: { "selection" => { "drena" => "abidjan-1" }, "expected_count" => 3 })
      @report = Entities::Catalog::ImportReport.new(
        id: 1, public_id: "rapport1", kind:, status:, format_version: nil, total_count: 0, imported_count: 0, skipped_count: 0,
        error_count: 0, processed_count: 0, details:, import_errors: [], imported_by_id: 7, started_at: nil, finished_at: nil,
        created_at: LAUNCH
      )
      @advances = []
    end

    def claim(id:, at:) = @report.status == "queued" && (@report = @report.with(status: "validating", started_at: at)) && true
    def resume(id:, at:) = %w[validating importing].include?(@report.status) && (@report = @report.with(started_at: at)) && true
    def find(id:) = @report

    def advance(id:, status:, processed_count:, format_version: nil)
      @advances << processed_count
      @report = @report.with(status:, processed_count:)
      true
    end

    def finish(id:, status:, counts:, details:, errors:, at:)
      @finished = { status:, counts:, details:, errors: errors.map { [ it.path, it.code ] } }
      @report = @report.with(status:, **counts, details:, import_errors: errors, finished_at: at)
      true
    end
  end

  class Users
    include Ports::Identity::UserRepositoryPort

    def initialize(actor) = @actor = actor
    def actor_for(user_id:) = @actor
  end

  class AuditLog
    include Ports::Identity::AuditLogPort

    attr_reader :events, :many

    def initialize
      @events = []
      @many = []
    end

    def record(**event) = (@events << event) && true
    def record_many(entries:) = @many.concat(entries).then { entries.size }
  end

  ADMIN = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")
  FIELD = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")

  def self.candidate(id, label, school_id: id, rotated_at: nil)
    Entities::School::RegenerationCandidate.new(id:, public_id: "p#{id}", label:, school_id:, rotated_at:)
  end
end
