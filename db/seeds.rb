# ADR-0034, amended by ADR-XXXX: one seed file per context, each loaded only in its environments. Production runs
# identity alone (the bootstrap invitation of the first team member); the referential, the DRENA and the schools are
# created by the team on screen or by import. A PR environment (Railway, run in production, PrEnvironment.active?)
# is seeded like development, plus the three test schools of the demo.
stage = PrEnvironment.active? ? "pr" : Rails.env
SEEDS = { "identity" => :all, "catalog" => %w[development test pr], "school" => %w[development test pr],
          "development" => %w[development pr], "demo/trois_etablissements" => %w[pr] }.freeze

SEEDS.each do |name, stages|
  next unless stages == :all || stages.include?(stage)

  load Rails.root.join("db/seeds/#{name}.rb")
end
