# ADR-0034: one seed file per context, each loaded only in its environments. Production runs identity alone
# (the bootstrap invitation of the first team member); the referential, the DRENA and the schools are created
# by the team on screen or by import.
SEEDS = { "identity" => :all, "catalog" => %w[development test], "school" => %w[development test], "development" => %w[development] }.freeze

SEEDS.each do |name, envs|
  next unless envs == :all || envs.include?(Rails.env)

  load Rails.root.join("db/seeds/#{name}.rb")
end
