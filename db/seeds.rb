# ADR-0034, amended by ADR-0108: one seed file per context, each loaded only in its environments. Production runs
# identity alone (the bootstrap invitation of the first team member); the referential, the DRENA and the schools are
# created by the team on screen or by import. A PR environment (Railway, run in production, PrEnvironment.active?)
# is seeded like development, plus the standard test set (db/seeds/standard.rb: three schools, their accounts and the
# lessons of the manifest, published; chantier standard-de-test), then its quarter of simulated activity
# (db/seeds/standard/activite.rb: sessions, grades, gaps and homework through the use cases; Lot B). In development the
# standard set and its activity are loaded by bin/jeu-standard. The former demo files stay available through
# bin/tester-pr --tout-contenu. Production Rails also runs
# contenus (Develop, Staging and production share it): the task loads the lessons with subjects on Develop and Staging only.
# The environment named Demo (DemoEnvironment, Lot H of standard-de-test) is a stage of its own: referential and standard set,
# never the repository lessons, the development accounts or the former demo files; its activity is simulated (standard/activite).
# Develop (Lot I of standard-de-test, ADR §4 point 5) also receives the schools, classrooms and accounts of the standard set and their
# activity, nothing deleted or changed; its lessons stay with contenus:charger. A failure of the set there is printed and logged, never raised.
# Staging (chantier comptes-de-test-staging, ADR-0124 §9) receives the same set without its activity (standard/activite) nor lessons: it keeps
# its :create_only loading (contenus:charger); a failure of the set there is printed and logged too.
load_stage = Entities::Catalog::AutomaticLoadStage.for(name: ENV["RAILWAY_ENVIRONMENT_NAME"], pr_environment: PrEnvironment.active?)
develop = load_stage.whole_lessons?
staging = load_stage.create_missing?
stage = if DemoEnvironment.active? then "demo"
elsif PrEnvironment.active? then "pr"
elsif Rails.env.production? && develop then "develop"
elsif Rails.env.production? && staging then "staging"
else Rails.env
end
SEEDS = { "identity" => :all, "contenus" => %w[production develop staging], "catalog" => %w[development test pr demo], "school" => %w[development test pr demo],
          "development" => %w[development pr], "standard" => %w[pr demo develop staging], "standard/activite" => %w[pr demo develop] }.freeze

SEEDS.each do |name, stages|
  next unless stages == :all || stages.include?(stage)

  load Rails.root.join("db/seeds/#{name}.rb")
rescue StandardError => error
  raise unless %w[develop staging].include?(stage) && name.start_with?("standard")

  site = stage.capitalize
  Rails.logger.error("[#{name}] semis impossible sur #{site} : #{error.class} : #{error.message}\n#{error.backtrace&.first(5)&.join("\n")}")
  puts "[#{name}] semis impossible sur #{site} : #{error.class} : #{error.message}"
end
