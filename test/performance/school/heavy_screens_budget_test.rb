require "test_helper"
require Rails.root.join("script/perf/dataset").to_s

# ADR-0067: the read budgets of the heavy screens, at the volume of the roadmap (script/perf/dataset.rb: 500 schools,
# 34 000 classrooms, 40 000 students, 312 000 sessions). This test checks the SQL of each screen, read by its query,
# against the p95 budget of the page: a query that alone exceeds it can only give a page over budget. The whole page
# (rendering, Rack) is measured by script/perf/measure_screens.rb. Skipped without PERF=1 (out of CI, ≈ 3 min).
#
# The dataset is committed, then vacuumed, as a production base would be: inside the transaction of a test, no page is
# all-visible and every index-only scan would go back to the table. The tables are emptied afterwards.
class School::HeavyScreensBudgetTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  RUNS = 15
  WARMUP = 3
  PILOTAGE_MS = 300
  SCREEN_MS = 100

  setup do
    skip "test de performance : lancez-le avec PERF=1" unless ENV["PERF"] == "1"
    load Rails.root.join("db/seeds.rb")
    create_team_member(contact: "0700000000", second_factor: false) # the content author of the dataset (db/seeds/development.rb)
    silence_stream($stdout) { PerfDataset.run }
    ActiveRecord::Base.connection.execute("VACUUM ANALYZE")
    @focus = Orm::SchoolStaff.joins(:user).find_by!(users: { contact: PerfDataset::ADMIN_CONTACT }).school_id
  end

  teardown do
    next unless ENV["PERF"] == "1"

    connection = ActiveRecord::Base.connection
    tables = connection.tables - [ ActiveRecord::Base.schema_migrations_table_name, ActiveRecord::Base.internal_metadata_table_name ]
    connection.execute("TRUNCATE #{tables.map { connection.quote_table_name(it) }.join(', ')} RESTART IDENTITY CASCADE")
  end

  # Every budget is played in one test: the dataset is seeded once.
  test "the dashboard, filtered or not, its search and the direction's home read within their budgets" do
    today = Date.current
    # La plus grande DRENA : la première ligne du tableau « Par DRENA », triée par élèves.
    largest = dashboard("7d", today).drenas.first.public_id
    budgets = {
      "pilotage 7 j" => [ PILOTAGE_MS, -> { dashboard("7d", today) } ],
      # Chiffres de l'année gardés 5 minutes (ADR-0062, amendement du 2026-09-29) : le budget porte sur l'entrée chaude.
      "pilotage année" => [ PILOTAGE_MS, -> { dashboard("year", today) } ],
      # UDR-0068 §3.6, ADR-0062 (amendement du 2026-10-03) : la page filtrée lit ses chiffres puis « Par établissement ».
      "pilotage filtré, plus grande DRENA" => [ PILOTAGE_MS, -> { filtered_dashboard("7d", today, largest) } ],
      "recherche « kou »" => [ SCREEN_MS, -> { Queries::Identity::AccountSearchQuery.new.call(term: "kou") } ],
      # UDR-0072 §3.2 : l'accueil de la direction (carte « Établissement » et « Niveaux ») remplace « Travail des élèves ».
      "Accueil" => [ SCREEN_MS, -> { Queries::School::DirectionHomeQuery.new.call(school_id: @focus) } ]
    }

    assert_operator Queries::Identity::AccountSearchQuery.new.call(term: "kou").total_count, :>, 1_000, "the worst case is measured"
    assert_equal 77, Queries::School::DirectionHomeQuery.new.call(school_id: @focus).figures.classrooms
    assert_operator filtered_dashboard("7d", today, largest).total, :>, 1, "the establishments of the largest DRENA are read"

    measured = budgets.transform_values { |budget, read| [ budget, p95_ms(&read) ] }

    measured.each { |name, (budget, p95)| puts format("\n[PERF] %-20s p95 %6.1f ms (budget %d ms)", name, p95, budget) }
    cold = p95_ms { dashboard("year", today, cache: ActiveSupport::Cache::NullStore.new) }
    puts format("\n[PERF] %-20s p95 %6.1f ms (à froid, une lecture toutes les 5 minutes au plus ; noté, non budgété)",
                "pilotage année", cold)
    measured.each { |name, (budget, p95)| assert_operator p95, :<, budget, name }
  end

  private

  def dashboard(key, today, cache: Rails.cache)
    Queries::School::TeamDashboardQuery.new(cache:).call(period: Entities::School::ReportingPeriod.parse(key, today:), today:)
  end

  # Les deux lectures de la page sous filtre DRENA, dans l'ordre du contrôleur.
  def filtered_dashboard(key, today, drena)
    period = Entities::School::ReportingPeriod.parse(key, today:)
    Queries::School::TeamDashboardQuery.new.call(period:, drena_public_id: drena, today:)
    Queries::School::DrenaSchoolsQuery.new.call(drena_public_id: drena, period:, today:)
  end

  def p95_ms(&read)
    ActiveRecord::Base.uncached do # every run reads the base (or Rails.cache), as a new request would
      WARMUP.times { read.call }
      times = Array.new(RUNS) do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        read.call
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
      end
      times.sort[((RUNS - 1) * 0.95).round]
    end
  end

  def silence_stream(stream)
    original = stream.dup
    stream.reopen(File::NULL)
    yield
  ensure
    stream.reopen(original)
  end
end
