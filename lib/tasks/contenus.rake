# Chargement automatique des leçons à sujets de devoir (ADR chargement-automatique-des-lecons-hors-production), sur Develop seul des
# leçons v3 du manifeste du jeu standard remplacées entières (ADR-0123, standard-de-test), sur Staging seul des leçons v3 absentes créées : lancé par
# db/seeds/contenus.rb au pré-déploiement Railway (`bin/rails db:prepare db:seed`). Develop et Staging seulement
# (RAILWAY_ENVIRONMENT_NAME), sous un verrou consultatif PostgreSQL ; ne sort jamais en erreur : le pré-déploiement n'échoue pas à cause d'elle.
namespace :contenus do
  desc "Charge les leçons du dépôt : à sujets de devoir (Develop et Staging, exercices et sujets seulement), v3 du jeu standard (Develop, entières), v3 absentes (Staging, créées), puis publication"
  task charger: :environment do
    say = ->(message) { puts "[contenus] #{message}" }
    connection = nil
    # Hors du cache de requêtes : un verrou se redemande, il ne se relit pas.
    advisory = ->(function) { connection.uncached { connection.select_value("SELECT #{function}(hashtext('contenus:charger'))") } }
    labels = { created: "créée(s)", ignored: "ignorée(s) (déjà présente)", replaced: "remplacée(s)", loaded: "à sujets rechargée(s)" }
    counts = ->(summary) { labels.map { |key, label| "#{summary.counts.fetch(key)} #{label}" }.join(", ") }
    locked = false
    begin
      connection = ActiveRecord::Base.connection
      locked = advisory.call("pg_try_advisory_lock")
      if locked
        transaction = Repositories::Shared::Transaction.new
        reports = Repositories::Catalog::ImportReportRepository.new
        files = Repositories::Catalog::ImportFileStore.new
        courses = Repositories::Catalog::CourseRepository.new
        essentials = Repositories::Catalog::EssentialRepository.new
        taxonomy = Repositories::Catalog::TaxonomyRepository.new
        users = Repositories::Identity::UserRepository.new
        # L'import tourne ici même : rien à mettre en file.
        no_queue = Object.new.tap { |queue| queue.define_singleton_method(:enqueue) { |**| nil } }
        adapter = ->(replace) { UseCases::Catalog::ImportCourseTree.new(courses:, essentials:, taxonomy:, writer: Repositories::Catalog::ContentTreeWriter.new, replace:) }
        dependencies = { audit_log: Repositories::Identity::AuditLogRepository.new, transaction:, policy: Policies::Catalog::ManageContentPolicy.new,
                         clock: Time.zone }
        exercises = Repositories::Assessment::ExerciseRepository.new
        run = lambda do |import_adapter|
          UseCases::Catalog::RunImport.new(adapter: import_adapter, schema: Repositories::Catalog::ImportSchemaValidator.new, reports:, files:,
                                           users:, audit_log: dependencies[:audit_log], transaction:, clock: Time.zone)
        end
        manifest = Entities::Catalog::StandardTestSet.new(YAML.load_file(Rails.root.join("db/seeds/standard/jeu.yml")))
        result = UseCases::Catalog::LoadRepositoryLessons.new(
          source: Repositories::Catalog::RepositoryLessonSource.new, reports:, users:, courses:, essentials:, exercises:, taxonomy:,
          start_import: UseCases::Catalog::StartImport.new(reports:, files:, queue: no_queue, transaction:, clock: Time.zone),
          run_import: run.call(adapter.call(:exercises)), run_lesson_import: run.call(adapter.call(:lesson)),
          run_create_import: run.call(adapter.call(:create_only)), manifest_paths: manifest.expected_paths,
          publish_cascade: UseCases::Catalog::PublishCascade.new(
            courses:, essentials:, exercises:, transaction:, policy: dependencies[:policy],
            publish_course: UseCases::Catalog::PublishCourse.new(courses:, **dependencies),
            publish_essential: UseCases::Catalog::PublishEssential.new(essentials:, **dependencies),
            publish_exercise: UseCases::Assessment::PublishExercise.new(exercises:, **dependencies)
          ),
          policy: dependencies[:policy], logger: Rails.logger, clock: Time.zone, referential: Repositories::Catalog::ReferentialCompleter.new
        ).call(environment_name: ENV["RAILWAY_ENVIRONMENT_NAME"], pr_environment: PrEnvironment.active?)
        if result.failure?
          say.call("chargement refusé (#{result.code}) : rien n'est chargé.")
        else
          summary = result.value
          messages = { skipped: "environnement sans chargement automatique : rien n'est chargé.",
                       no_author: "aucun membre d'équipe actif : rien n'est chargé.",
                       unknown_environment: "environnement non reconnu (#{ENV['RAILWAY_ENVIRONMENT_NAME'].to_s.strip}) : rien n'est chargé, " \
                                            "une ligne refusée est dans Imports.",
                       done: "#{summary.lessons.size} leçon(s) examinée(s) : #{counts.call(summary)}." }
          say.call(messages.fetch(summary.outcome))
          summary.lessons.each { |name, status| say.call("#{name} : #{status}") }
        end
      else
        say.call("un autre démarrage charge déjà les leçons : rien n'est chargé cette fois, le déploiement suivant reprendra.")
        Rails.logger.warn("[contenus] verrou pris par un autre démarrage : chargement sauté")
      end
    rescue StandardError => error
      Rails.logger.error("[contenus] chargement automatique interrompu : #{error.class} : #{error.message}")
      say.call("chargement automatique interrompu : #{error.class} : #{error.message}")
    ensure
      begin
        advisory.call("pg_advisory_unlock") if locked
      rescue StandardError => error
        Rails.logger.error("[contenus] verrou non rendu : #{error.class} : #{error.message}")
      end
    end
  end
end
