# ADR chargement-automatique-des-lecons-hors-production: played by Railway's pre-deploy (`db:prepare db:seed`, .railway/railway.ts), in
# production Rails on Develop, Staging and production alike; a PR environment does not get it (it seeds its own lessons). The task
# decides by RAILWAY_ENVIRONMENT_NAME (Develop and Staging load, production and anything silent do nothing, an unknown name leaves a
# refused line in Imports) and never raises: the pre-deploy must not fail because of lessons.
begin
  require "rake"
  Rails.application.load_tasks unless Rake::Task.task_defined?("contenus:charger")
  Rake::Task["contenus:charger"].reenable
  Rake::Task["contenus:charger"].invoke
rescue StandardError => error
  Rails.logger.error("[contenus] chargement automatique impossible : #{error.class} : #{error.message}")
  puts "[contenus] chargement automatique impossible : #{error.class} : #{error.message}"
end
