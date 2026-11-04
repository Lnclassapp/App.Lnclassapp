# Mesure des pages par rôle sur le grand établissement : `bin/pages-lentes [--seuil=ms] [--role=...]`, ou `bin/rails pages:lentes`
# (variables PAGES_LENTES_SEUIL, PAGES_LENTES_REQUETES, PAGES_LENTES_ROLE, PAGES_LENTES_ECOLE, PAGES_LENTES_CHAUFFE).
# Développement seulement : la tâche se connecte avec le PIN du jeu de test et ne change rien dans la base (hors sessions de connexion).
namespace :pages do
  desc "Visite les pages de chaque rôle d'un établissement (development), mesure temps et requêtes SQL, signale les pages lentes"
  task lentes: :environment do
    stop = ->(message) { abort("[pages-lentes] #{message}") }
    stop.call("refusé : la mesure ne tourne qu'en development (environnement actuel : #{Rails.env}). Rien n'est visité.") unless Rails.env.development?

    require Rails.root.join("script/pages_lentes")
    stop.call("refusé : RAILWAY_ENVIRONMENT_NAME ou DATABASE_URL est posée (base distante possible). Rien n'est visité.") if ENV["RAILWAY_ENVIRONMENT_NAME"].present? || ENV["DATABASE_URL"].present?
    stop.call("refusé : l'hôte de la base configurée n'est pas local. Rien n'est visité.") unless PagesLentes.local_database?

    names = YAML.load_file(Rails.root.join("db/seeds/standard/noms.yml"))
    name = ENV["PAGES_LENTES_ECOLE"].presence || Entities::School::FictitiousIdentity.new(names).school_name("grand")
    school = Orm::School.find_by(name:)
    stop.call("établissement introuvable : #{name.inspect} (bin/jeu-standard d'abord).") if school.nil?

    role = ENV["PAGES_LENTES_ROLE"].presence
    threshold = Float(ENV.fetch("PAGES_LENTES_SEUIL", "500"))
    max_queries = Integer(ENV.fetch("PAGES_LENTES_REQUETES", "100"))

    # Mesure fidèle : ni traces d'appel des requêtes ni Bullet ne comptent dans le temps d'une page.
    ActiveRecord.verbose_query_logs = false
    Bullet.enable = false
    runner = PagesLentes::Runner.new(school:, roles: Array(role || PagesLentes::ROLES), warmup: Integer(ENV.fetch("PAGES_LENTES_CHAUFFE", "1")))
    puts "Pages de #{school.name} (#{Orm::Classroom.where(school_id: school.id).count} classes), temps serveur sans navigateur, page chauffée avant mesure."
    puts PagesLentes.report(runner.call, threshold:, max_queries:)
    exit 1 if PagesLentes.failed?(runner)
  end
end
