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
stage = if DemoEnvironment.active? then "demo" elsif PrEnvironment.active? then "pr" else Rails.env end
SEEDS = { "identity" => :all, "contenus" => %w[production], "catalog" => %w[development test pr demo], "school" => %w[development test pr demo],
          "development" => %w[development pr], "standard" => %w[pr demo], "standard/activite" => %w[pr demo] }.freeze

SEEDS.each do |name, stages|
  next unless stages == :all || stages.include?(stage)

  load Rails.root.join("db/seeds/#{name}.rb")
end
