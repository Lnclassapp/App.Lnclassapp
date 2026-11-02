# 🧠 DOMAINE · UseCases::Catalog::LoadRepositoryLessons
# Rôle : Develop et Staging chargent les leçons à sujets de devoir du dépôt ; Develop remplace entières les seules leçons du manifeste du jeu standard, Staging crée les leçons v3 absentes sans toucher aux présentes ; production jamais
# ADR  : chargement-automatique-des-lecons-hors-production, standard-de-test, 0123, 0108, 0113, 0116, 0121
module UseCases
  module Catalog
    class LoadRepositoryLessons
      KIND = "course_tree"
      # Le début du nom de fichier de chaque ligne d'import du chargement automatique (RepositoryLessonSource).
      IMPORT_PREFIX = "chargement-automatique-"
      # Journal d'un import refusé : ses premières erreurs, et seulement ces paramètres (aucune donnée personnelle).
      LOGGED_ERRORS = 3
      LOGGED_PARAMS = %i[keyword rule exception constraint].freeze
      # value n'est écrit que pour ces codes : il y nomme un niveau, une matière ou une série du fichier (jamais un texte de leçon).
      LOGGED_VALUE_CODES = %w[unknown_level unknown_material unknown_series series_not_allowed].freeze

      # outcome : :skipped (production, PR, nom absent), :no_author (aucun membre d'équipe actif), :unknown_environment (une ligne refusée
      # est laissée), :done. lessons : { nom d'import => :loaded | :created | :replaced | :unchanged | :not_started | :refused | :unpublished |
      # :partially_published | :republished | :failed | :ignored } ; :created et :replaced disent qu'une leçon du programme v3 (ADR-0123) a été
      # écrite absente ou à la place de celle du même titre, :loaded qu'une leçon à sujets de devoir l'a été (ADR-0122), :ignored qu'une leçon
      # déjà présente a été laissée intacte (Staging, mode create_only).
      STATUSES = %i[created ignored replaced loaded unchanged republished failed refused not_started unpublished partially_published].freeze
      # Les statuts qui disent un échec ou une publication incomplète.
      TROUBLES = %i[failed refused not_started unpublished partially_published].freeze
      Summary = Data.define(:outcome, :lessons) do
        def initialize(lessons: {}, **) = super

        # Le rapport de chargement : le nombre de leçons par statut (tous, à zéro quand il n'y en a pas) ; la somme égale le nombre de fichiers.
        def counts = LoadRepositoryLessons::STATUSES.to_h { |status| [ status, lessons.values.count(status) ] }
      end

      # source : LessonSourcePort ; reports : ImportReportRepositoryPort ; users : UserRepositoryPort ; courses, essentials, exercises : les repositories
      # du même nom (fiches et exercices en brouillon d'une leçon) ; logger : le journal du déploiement ;
      # taxonomy : TaxonomyRepository (lookup) ; start_import, run_import, publish_cascade : les use cases du même nom, cablés par l'appelant
      # (run_import avec l'adaptateur ImportCourseTree en mode replace: :exercises, run_lesson_import en mode replace: :lesson, run_create_import en
      # mode replace: :create_only) ; manifest_paths : les chemins « niveau/matière/fichier.json » du jeu standard (StandardTestSet#expected_paths),
      # les seuls fichiers que Develop remplace entiers ;
      # policy : Policies::Catalog::ManageContentPolicy ; referential : ReferentialCompleterPort (Develop seul, ADR-0123 §8).
      def initialize(source:, reports:, users:, courses:, essentials:, exercises:, taxonomy:, start_import:, run_import:, run_lesson_import:,
                     run_create_import:, manifest_paths:, publish_cascade:, policy:, logger:, clock:, referential:)
        @source = source
        @reports = reports
        @users = users
        @courses = courses
        @essentials = essentials
        @exercises = exercises
        @taxonomy = taxonomy
        @start_import = start_import
        @run_import = run_import
        @run_lesson_import = run_lesson_import
        @run_create_import = run_create_import
        @manifest = manifest_paths.to_set { "#{IMPORT_PREFIX}#{it.tr('/', '-')}" }
        @referential = referential
        @publish_cascade = publish_cascade
        @policy = policy
        @logger = logger
        @clock = clock
      end

      # → Result(Summary) | :forbidden (l'auteur n'a plus le droit de gérer les contenus). Les erreurs d'un fichier restent dans sa ligne d'import ;
      # une exception sur une leçon est journalisée avec son nom (statut :failed) et les leçons suivantes sont tentées.
      def call(environment_name:, pr_environment:)
        stage = Entities::Catalog::AutomaticLoadStage.for(name: environment_name, pr_environment:)
        return done(:skipped) if stage.skip?

        actor = @users.oldest_active_team_actor
        return done(:no_author) if actor.nil?

        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return reject_unknown(stage, actor) if stage.unknown?

        fail_orphans
        complete_referential if stage.whole_lessons?
        chosen, ignored = @source.lessons.map { [ it, mode_of(stage, it) ] }.partition(&:last)
        log_ignored(ignored.map(&:first))
        done(:done, chosen.to_h { |lesson, mode| [ lesson.import_name, load_safely(lesson, mode, actor) ] })
      end

      private

      def mode_of(stage, lesson)
        stage.mode_for(level_directory: lesson.level_directory, subjects: lesson.subjects, in_manifest: @manifest.include?(lesson.import_name))
      end

      def done(outcome, lessons = {}) = Shared::Result.success(Summary.new(outcome:, lessons:))

      def reject_unknown(stage, actor)
        error = Entities::Catalog::ImportError.new(path: "$", code: "unknown_environment", params: { name: stage.name })
        @reports.record_rejection(kind: KIND, checksum_sha256: Digest::SHA256.hexdigest("unknown_environment:#{stage.name}"),
                                  imported_by_id: actor.user_id, at: @clock.now, errors: [ error ])
        done(:unknown_environment)
      end

      # ADR-0123 §9 : un chargement tué en pleine leçon (déploiement remplacé) laisse son rapport « en cours », qui ferait refuser tout import
      # du type pendant 10 minutes (StartImport) ; sous le verrou consultatif, aucun autre chargement ne tourne : ces rapports sont orphelins.
      # Un échec ici est journalisé et le chargement continue (les leçons qui buteraient sur l'orphelin sont alors not_started).
      def fail_orphans
        failed = @reports.fail_running_named(kind: KIND, prefix: IMPORT_PREFIX, at: @clock.now)
        @logger.warn("[contenus] #{failed.size} import(s) d'un chargement interrompu passé(s) en échec : #{failed.join(', ')}") if failed.any?
      rescue StandardError => error
        @logger.error("[contenus] imports interrompus non nettoyés (#{error.class} : #{error.message})")
      end

      # ADR-0123 §8 : Develop seul crée, avant le chargement, ce qui manque du référentiel de base ; journalisé. Un échec ne bloque rien.
      def complete_referential
        created = @referential.complete
        parts = { levels: "niveaux", series: "séries", pairs: "couples", materials: "matières" }
                .filter_map { |key, label| "#{label} #{created.fetch(key).join(', ')}" if created.fetch(key).any? }
        parts << "barème #{created.fetch(:plan_entries).size} entrée(s)" if created.fetch(:plan_entries).any?
        parts << "DRENA #{created.fetch(:drenas).size}" if created.fetch(:drenas).any?
        @logger.info("[contenus] référentiel complété : #{parts.join(' ; ')}") if parts.any?
        conflicts = created.fetch(:conflicts)
        @logger.warn("[contenus] référentiel : non créé (déjà pris) : #{conflicts.join(', ')}") if conflicts.any?
        interruptions = created.fetch(:interruptions)
        @logger.error("[contenus] référentiel interrompu : #{interruptions.join(' ; ')}") if interruptions.any?
      rescue StandardError => error
        @logger.error("[contenus] référentiel non complété (#{error.class} : #{error.message})")
      end

      # Une ligne par démarrage : les fichiers v3 lus mais pas chargés ici, comptés par dossier de niveau (une vague mal rangée se voit).
      def log_ignored(lessons)
        return if lessons.empty?

        counts = lessons.map(&:level_directory).tally.sort.map { |folder, count| "#{folder} #{count}" }
        @logger.info("[contenus] fichier(s) v3 non chargé(s) ici : #{counts.join(', ')}")
      end

      def load_safely(lesson, mode, actor)
        load(lesson, mode, actor)
      rescue StandardError => error
        @logger.error("[contenus] #{lesson_name(lesson)} : échec (#{error.class} : #{error.message})")
        :failed
      end

      def load(lesson, mode, actor)
        return :ignored if mode == :create_only && present?(lesson)
        return republish(lesson, actor) if @reports.last_loaded_checksum(kind: KIND, file_name: lesson.import_name) == lesson.checksum_sha256

        loaded = { lesson: -> { present?(lesson) ? :replaced : :created }, create_only: -> { :created } }.fetch(mode) { -> { :loaded } }.call

        upload = Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new(lesson.content), filename: lesson.import_name)
        started = @start_import.call(actor:, dto: Dtos::Catalog::ImportUploadInput.new(kind: KIND, files: [ upload ]))
        if started.failure?
          @logger.error("[contenus] #{lesson_name(lesson)} : import non démarré (#{started.code} #{started.errors})")
          return :not_started
        end

        ran = { lesson: @run_lesson_import, create_only: @run_create_import }.fetch(mode, @run_import).call(report_id: started.value.id)
        if ran.failure?
          @logger.error("[contenus] #{lesson_name(lesson)} : import en échec (#{ran.code})")
          return :refused
        end
        unless ran.value.status == "completed" && ran.value.error_count.zero?
          @logger.warn("[contenus] #{lesson_name(lesson)} : import refusé (#{ran.value.status}, #{ran.value.error_count} erreur(s)), voir Imports" \
                       "#{refusal_reasons(ran.value)}")
          return :refused
        end

        return :ignored if mode == :create_only && ran.value.imported_count.zero?

        if loaded != :loaded
          @logger.info("[contenus] #{lesson_name(lesson)} : leçon #{loaded == :replaced ? 'remplacée entière' : 'créée'} (#{lesson.import_name})")
        end
        guarded(lesson) { publish(lesson, actor, slug_of(lesson), loaded) }
      end

      # Les LOGGED_ERRORS premières erreurs du rapport : code, chemin et paramètres sûrs (nom du référentiel, mot-clé de schéma, exception
      # et contrainte d'une écriture refusée). Ni nom de leçon ou de notion, ni texte du fichier, ni donnée d'élève. Ne lève jamais : le refus
      # reste journalisé comme refus.
      def refusal_reasons(report)
        reasons = Array(report.import_errors).first(LOGGED_ERRORS).map do |error|
          keys = LOGGED_VALUE_CODES.include?(error.code) ? [ :value, *LOGGED_PARAMS ] : LOGGED_PARAMS
          safe = error.params.to_h.transform_keys(&:to_sym).slice(*keys)
          details = safe.map { |key, value| "#{key}: #{value.to_s.truncate(60)}" }.join(", ")
          [ error.code, error.path, ("(#{details})" if safe.any?) ].compact.join(" ")
        end
        reasons.empty? ? "" : " : #{reasons.join(' ; ')}"
      rescue StandardError
        ""
      end

      # Fichier inchangé : pas de réimport, mais une publication qui a échoué après un import réussi est reprise (même critère que
      # db/seeds/demo/lecons_completes.rb : cours publié, aucun brouillon restant). Tout publié : rien.
      def republish(lesson, actor)
        guarded(lesson) do
          slug = slug_of(lesson)
          next :unchanged unless pending_publication?(slug)

          publish(lesson, actor, slug, :republished)
        end
      end

      def pending_publication?(slug)
        course = @courses.find_by_slug(slug:)
        course.status != "published" || @exercises.draft_public_ids(course_id: course.id).any? || @essentials.draft_slugs(course_id: course.id).any?
      end

      # La cascade de publication, journalisée ; un échec ne touche ni l'import ni les autres leçons.
      def publish(lesson, actor, slug, done)
        result = @publish_cascade.call(actor:, root: :course, slug:)
        if result.failure?
          @logger.error("[contenus] #{lesson_name(lesson)} : publication refusée (#{result.code})")
          return :unpublished
        end

        skipped = result.value.skipped
        if skipped.positive?
          @logger.warn("[contenus] #{lesson_name(lesson)} : #{skipped} exercice(s) laissé(s) en brouillon (non publiables), #{result.value.exercises} publié(s)")
          return :partially_published
        end

        @logger.info("[contenus] #{lesson_name(lesson)} : publiée, #{result.value.exercises} exercice(s) publié(s)")
        done
      end

      def guarded(lesson)
        yield
      rescue StandardError => error
        @logger.error("[contenus] #{lesson_name(lesson)} : publication interrompue (#{error.class} : #{error.message})")
        :unpublished
      end

      def lesson_name(lesson) = JSON.parse(lesson.content).fetch("courses").first["name"].to_s.squish

      # La leçon que l'import vient d'écrire (ou de remplacer), retrouvée par la clé de doublon de l'import.
      def slug_of(lesson) = @courses.slugs_by_key.fetch(key_of(lesson))

      # Avant l'import : une leçon du même titre (niveau, matière, série) est-elle déjà là ? Un niveau ou une matière inconnus : non (l'import
      # refusera la leçon dans sa ligne).
      def present?(lesson) = @courses.slugs_by_key.key?(key_of(lesson))

      def key_of(lesson)
        course = JSON.parse(lesson.content).fetch("courses").first
        lookup = @taxonomy.lookup
        [ Entities::Shared::NaturalKey.compact(course["name"].to_s.squish), lookup.resolve_level(course["level_name"])&.id,
          lookup.resolve_material(course["material_name"])&.id, lookup.resolve_series(course["series_name"])&.id ]
      end
    end
  end
end
